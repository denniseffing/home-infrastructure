"""Tests the exact hook embedded in the Helm values ConfigMap, without network I/O."""

from copy import deepcopy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import MagicMock, Mock, patch
from urllib.error import HTTPError, URLError

import yaml


APP_DIR = Path(__file__).resolve().parents[1] / "app"
CONFIGMAP = yaml.safe_load((APP_DIR / "configmap.yaml").read_text())
VALUES = yaml.safe_load(CONFIGMAP["data"]["values.yaml"])
SCRIPT = VALUES["configMaps"]["scripts"]["data"]["post-import-scan.py"]


class ScanHookTests(unittest.TestCase):
    def setUp(self):
        self.hook = types.ModuleType("post_import_scan")
        exec(compile(SCRIPT, "post-import-scan.py", "exec"), self.hook.__dict__)
        self.temp = tempfile.TemporaryDirectory(prefix="shelfmark-hook-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "audiobooks"
        self.root.mkdir()
        self.hook.LIBRARY_ROOT = self.root
        self.target = self.root / "Author" / "Title" / "01.mp3"
        self.payload = {
            "version": 1,
            "phase": "post_transfer",
            "output": {"mode": "folder"},
            "paths": {
                "destination": str(self.root),
                "target": str(self.target),
                "final_paths": [str(self.target)],
            },
        }
        self.environ = {
            "AUDIOBOOKSHELF_URL": "http://audiobookshelf.default.svc.cluster.local",
            "AUDIOBOOKSHELF_TOKEN": "test-token-never-log",
            "ABS_SCAN_LIBRARY_ID": "8715fc43-44c6-4843-9e94-96c056873511",
        }
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, self.environ, clear=True).start()
        self.stderr = io.StringIO()
        patch.object(sys, "stderr", self.stderr).start()
        self.sleep = patch.object(self.hook.time, "sleep").start()
        self.opener = Mock()
        self.build_opener = patch.object(
            self.hook, "build_opener", return_value=self.opener
        ).start()

    @staticmethod
    def response(status=200):
        response = MagicMock()
        response.status = status
        response.__enter__.return_value = response
        return response

    @staticmethod
    def http_error(status):
        return HTTPError("http://abs/scan", status, "test-token-never-log", {}, None)

    def run_main(self, raw=None, argv=None):
        if raw is None:
            raw = json.dumps(self.payload)
        if argv is None:
            argv = ["post-import-scan.py", str(self.target)]
        with (
            patch.object(sys, "stdin", io.StringIO(raw)),
            patch.object(sys, "argv", argv),
            patch.object(self.hook.signal, "signal") as handler,
            patch.object(self.hook.signal, "alarm") as alarm,
        ):
            self.assertEqual(self.hook.main(), 0)
            self.assertEqual(alarm.call_args_list[0].args, (240,))
            self.assertEqual(alarm.call_args_list[-1].args, (0,))
            self.assertEqual(handler.call_count, 2)

    def test_single_file_payload(self):
        self.assertTrue(self.hook.validate_payload(self.payload, str(self.target)))

    def test_multiple_files_use_common_parent(self):
        self.payload["paths"]["target"] = str(self.target.parent)
        self.payload["paths"]["final_paths"].append(str(self.target.with_name("02.mp3")))
        self.assertTrue(self.hook.validate_payload(self.payload, str(self.target.parent)))

    def test_non_transfer_phases_and_outputs_are_ignored(self):
        for phase in ["post_upload", "post_email", None]:
            with self.subTest(phase=phase):
                payload = deepcopy(self.payload)
                payload["phase"] = phase
                self.assertFalse(self.hook.validate_payload(payload, str(self.target)))
        for mode in ["email", "booklore", None]:
            with self.subTest(mode=mode):
                payload = deepcopy(self.payload)
                payload["output"]["mode"] = mode
                self.assertFalse(self.hook.validate_payload(payload, str(self.target)))

    def test_invalid_payload_shapes(self):
        invalid = [None, [], "text", {}]
        for key, value in [
            ("version", "1"),
            ("version", 2),
            ("version", True),
            ("output", []),
            ("paths", None),
        ]:
            payload = deepcopy(self.payload)
            payload[key] = value
            invalid.append(payload)
        for payload in invalid:
            with self.subTest(payload=payload):
                with self.assertRaises(ValueError):
                    self.hook.validate_payload(payload, str(self.target))

    def test_all_paths_are_bounded_and_absolute(self):
        invalid = [
            None,
            123,
            "",
            "relative/01.mp3",
            "/downloads/01.mp3",
            str(self.root) + "-other/01.mp3",
            str(self.root / ".." / "outside.mp3"),
            str(self.root / "bad\x00name.mp3"),
        ]
        for key in ["destination", "target", "final_paths"]:
            for value in invalid:
                with self.subTest(key=key, value=value):
                    payload = deepcopy(self.payload)
                    payload["paths"][key] = [value] if key == "final_paths" else value
                    with self.assertRaises(ValueError):
                        self.hook.validate_payload(payload, str(self.target))

    def test_final_paths_must_be_nonempty_list(self):
        for value in [None, [], str(self.target), {}]:
            with self.subTest(value=value):
                self.payload["paths"]["final_paths"] = value
                with self.assertRaises(ValueError):
                    self.hook.validate_payload(self.payload, str(self.target))

    def test_paths_must_stay_within_destination(self):
        self.payload["paths"]["destination"] = str(self.target.parent)
        self.payload["paths"]["final_paths"] = [str(self.root / "other.mp3")]
        with self.assertRaises(ValueError):
            self.hook.validate_payload(self.payload, str(self.target))

    def test_target_argument_must_match(self):
        with self.assertRaises(ValueError):
            self.hook.validate_payload(self.payload, str(self.target.with_name("other.mp3")))

    def test_symlink_escape_is_rejected(self):
        link = self.root / "outside"
        link.symlink_to(self.root.parent, target_is_directory=True)
        self.payload["paths"]["final_paths"] = [str(link / "outside.mp3")]
        with self.assertRaises(ValueError):
            self.hook.validate_payload(self.payload, str(self.target))

    def test_filenames_are_data_not_commands(self):
        target = self.target.with_name("$(touch NEVER); 'part 1'.mp3")
        self.payload["paths"]["target"] = str(target)
        self.payload["paths"]["final_paths"] = [str(target)]
        self.assertTrue(self.hook.validate_payload(self.payload, str(target)))

    def test_valid_hook_requests_scan_without_force(self):
        self.opener.open.return_value = self.response()
        self.run_main()
        self.opener.open.assert_called_once()
        request = self.opener.open.call_args.args[0]
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(
            request.full_url,
            self.environ["AUDIOBOOKSHELF_URL"]
            + "/api/libraries/8715fc43-44c6-4843-9e94-96c056873511/scan",
        )
        self.assertEqual(request.get_header("Authorization"), "Bearer test-token-never-log")
        self.assertEqual(request.data, b"{}")
        self.assertEqual(self.opener.open.call_args.kwargs["timeout"], 60)
        self.sleep.assert_not_called()
        self.assertIn("accepted the library scan", self.stderr.getvalue())
        self.assertNotIn("test-token-never-log", self.stderr.getvalue())

    def test_scan_retries_transient_errors_and_succeeds(self):
        self.opener.open.side_effect = [
            self.http_error(503), URLError("test-token-never-log"), self.response(202)
        ]
        self.run_main()
        self.assertEqual(self.opener.open.call_count, 3)
        self.assertEqual([call.args[0] for call in self.sleep.call_args_list], [5, 10])
        self.assertIn("accepted the library scan", self.stderr.getvalue())
        self.assertNotIn("test-token-never-log", self.stderr.getvalue())

    def test_retryable_http_statuses(self):
        for status in [408, 429, 500, 502, 504]:
            with self.subTest(status=status):
                self.opener.open.reset_mock()
                self.sleep.reset_mock()
                self.opener.open.side_effect = [self.http_error(status), self.response()]
                self.hook.scan_library()
                self.assertEqual(self.opener.open.call_count, 2)
                self.sleep.assert_called_once_with(5)

    def test_client_errors_and_redirects_are_not_retried(self):
        for status in [301, 302, 307, 400, 401, 403, 404]:
            with self.subTest(status=status):
                self.opener.open.reset_mock()
                self.opener.open.side_effect = self.http_error(status)
                self.run_main()
                self.opener.open.assert_called_once()
        self.sleep.assert_not_called()
        self.assertNotIn("test-token-never-log", self.stderr.getvalue())

    def test_scan_failure_keeps_import_and_never_raises(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_bytes(b"existing audiobook")
        self.opener.open.side_effect = TimeoutError("test-token-never-log")
        self.run_main()
        self.assertEqual(self.opener.open.call_count, 3)
        self.assertEqual(self.target.read_bytes(), b"existing audiobook")
        self.assertIn("import kept", self.stderr.getvalue())
        self.assertNotIn("test-token-never-log", self.stderr.getvalue())

    def test_invalid_scan_configuration_does_not_call_api(self):
        invalid = [
            ("AUDIOBOOKSHELF_URL", ""),
            ("AUDIOBOOKSHELF_URL", "ftp://abs"),
            ("AUDIOBOOKSHELF_URL", "http://user:secret@abs"),
            ("AUDIOBOOKSHELF_URL", "http://abs?secret=value"),
            ("AUDIOBOOKSHELF_URL", "http://abs#fragment"),
            ("AUDIOBOOKSHELF_TOKEN", ""),
            ("AUDIOBOOKSHELF_TOKEN", "secret\ninjected"),
            ("ABS_SCAN_LIBRARY_ID", ""),
            ("ABS_SCAN_LIBRARY_ID", "id/../other"),
            ("ABS_SCAN_LIBRARY_ID", "id?force=1"),
        ]
        for key, value in invalid:
            with self.subTest(key=key, value=value):
                with patch.dict(os.environ, {key: value}):
                    self.run_main()
        self.opener.open.assert_not_called()

    def test_global_deadline_is_not_swallowed_as_network_error(self):
        self.opener.open.side_effect = self.hook.HookDeadlineExceeded()
        self.run_main()
        self.opener.open.assert_called_once()
        self.sleep.assert_not_called()
        self.assertIn("deadline reached", self.stderr.getvalue())
        self.assertLess(self.hook.HOOK_TIMEOUT_SECONDS, 300)
        self.assertLess(
            self.hook.HTTP_TIMEOUT_SECONDS * 3 + sum(self.hook.RETRY_DELAYS_SECONDS),
            self.hook.HOOK_TIMEOUT_SECONDS,
        )

    def test_invalid_input_and_arguments_exit_successfully(self):
        for raw in ["", "not json", "null", "[]", '{"version":', "[" * 2000]:
            with self.subTest(raw=raw[:30]):
                self.run_main(raw=raw)
        self.run_main(raw="x" * (self.hook.MAX_PAYLOAD_CHARS + 1))
        self.run_main(argv=["post-import-scan.py"])
        self.run_main(argv=["post-import-scan.py", str(self.target), "extra"])
        self.opener.open.assert_not_called()

    def test_ignored_phase_makes_no_api_call(self):
        self.payload["phase"] = "post_upload"
        self.run_main()
        self.opener.open.assert_not_called()

    def test_redirect_handler_never_forwards_token(self):
        handler = self.hook.NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, "", {}, "https://other"))

    def test_container_logs_are_visible_despite_captured_stderr(self):
        with (
            patch.dict(os.environ, {"DOCKERMODE": "true"}),
            patch.object(sys, "platform", "linux"),
            patch.object(os, "getppid", return_value=123),
            patch.object(os, "open", return_value=42) as open_fd,
            patch.object(os, "write") as write_fd,
            patch.object(os, "close") as close_fd,
        ):
            self.hook.log("Scan unavailable; import kept.")
            open_fd.assert_called_once_with("/proc/123/fd/1", os.O_WRONLY | os.O_NONBLOCK)
            self.assertIn(b"import kept", write_fd.call_args.args[1])
            close_fd.assert_called_once_with(42)

    def test_unavailable_parent_log_fd_is_nonfatal(self):
        with (
            patch.dict(os.environ, {"DOCKERMODE": "true"}),
            patch.object(sys, "platform", "linux"),
            patch.object(os, "open", side_effect=PermissionError),
        ):
            self.hook.log("Scan unavailable; import kept.")
        self.assertIn("import kept", self.stderr.getvalue())

    def test_broken_stderr_does_not_fail_import(self):
        with patch.object(sys, "stderr") as stderr:
            stderr.write.side_effect = BrokenPipeError
            self.run_main(raw="invalid json")
        self.opener.open.assert_not_called()

    def test_executable_cli_returns_zero_for_invalid_payload(self):
        script_path = Path(self.temp.name) / "post-import-scan.py"
        script_path.write_text(SCRIPT)
        result = subprocess.run(
            [sys.executable, "-B", str(script_path), "/downloads/outside.mp3"],
            input="invalid json",
            text=True,
            capture_output=True,
            timeout=5,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("import kept", result.stderr)
        self.opener.open.assert_not_called()


class ManifestConfigurationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.release = yaml.safe_load((APP_DIR / "helmrelease.yaml").read_text())
        cls.values = cls.release["spec"]["values"]

    def test_single_hardened_controller(self):
        controllers = self.values["controllers"]
        self.assertEqual(list(controllers), ["shelfmark"])
        controller = controllers["shelfmark"]
        self.assertEqual(controller["replicas"], 1)
        self.assertEqual(controller["strategy"], "Recreate")
        self.assertEqual(list(controller["containers"]), ["app"])
        container = controller["containers"]["app"]
        self.assertNotIn("initContainers", controller)
        self.assertIn("1.7.0@sha256:", container["image"]["tag"])
        self.assertTrue(container["securityContext"]["readOnlyRootFilesystem"])
        self.assertFalse(container["securityContext"]["allowPrivilegeEscalation"])
        self.assertEqual(container["securityContext"]["capabilities"]["drop"], ["ALL"])
        security = self.values["defaultPodOptions"]["securityContext"]
        for key in ["runAsUser", "runAsGroup", "fsGroup"]:
            self.assertEqual(security[key], 1000)
        self.assertTrue(security["runAsNonRoot"])
        self.assertEqual(security["seccompProfile"]["type"], "RuntimeDefault")

    def test_paths_copy_mode_and_library_id(self):
        persistence = self.values["persistence"]
        downloads = persistence["downloads"]
        self.assertEqual(downloads["type"], "nfs")
        self.assertEqual(
            downloads["path"],
            "/nfs/storage-2/plex/downloads/usenet/complete/shelfmark-audiobooks",
        )
        self.assertEqual(downloads["globalMounts"], [{"path": "/downloads", "readOnly": True}])
        self.assertEqual(persistence["config"]["existingClaim"], "shelfmark-config")
        self.assertNotEqual(persistence["tmp"].get("medium"), "Memory")
        self.assertEqual(persistence["home"]["globalMounts"][0]["path"], "/home/shelfmark")
        env = self.values["controllers"]["shelfmark"]["containers"]["app"]["env"]
        self.assertEqual(env["PROWLARR_USENET_ACTION"], "copy")
        self.assertEqual(env["HARDLINK_TORRENTS_AUDIOBOOK"], "false")
        self.assertEqual(env["AUDIOBOOKSHELF_LIBRARY_IDS"], env["ABS_SCAN_LIBRARY_ID"])
        self.assertNotIn("PROWLARR_REMOTE_PATH_MAPPINGS", env)
        self.assertEqual(env["OPENLIBRARY_ENABLED"], "true")

    def test_internal_route_without_auth_exception(self):
        self.assertEqual(list(self.values["route"]), ["app"])
        route = self.values["route"]["app"]
        self.assertEqual(route["hostnames"], ["shelfmark.internal.denniseffing.de"])
        self.assertEqual(route["parentRefs"], [{"name": "envoy-internal", "namespace": "network"}])
        self.assertFalse((APP_DIR / "securitypolicy.yaml").exists())

    def test_values_checksum_rollout_and_executable_mount(self):
        self.assertEqual(
            self.release["spec"]["valuesFrom"],
            [{"kind": "ConfigMap", "name": "shelfmark-values", "valuesKey": "values.yaml"}],
        )
        self.assertEqual(CONFIGMAP["metadata"]["labels"]["reconcile.fluxcd.io/watch"], "Enabled")
        self.assertTrue(VALUES["configMaps"]["scripts"]["includeInChecksum"])
        scripts = self.values["persistence"]["scripts"]
        self.assertEqual(scripts["identifier"], "scripts")
        self.assertEqual(scripts["defaultMode"], 0o555)

    def test_secrets_are_explicitly_mapped(self):
        secret = yaml.safe_load((APP_DIR / "externalsecret.yaml").read_text())
        self.assertEqual(
            [(entry["remoteRef"]["key"], entry["remoteRef"]["property"], entry["secretKey"])
             for entry in secret["spec"]["data"]],
            [("prowlarr", "api-key", "PROWLARR_API_KEY"),
             ("sabnzbd", "api-key", "SABNZBD_API_KEY"),
             ("shelfmark", "audiobookshelf-api-token", "AUDIOBOOKSHELF_TOKEN")],
        )

    def test_pvc_has_backups_and_is_not_pruned(self):
        pvc = yaml.safe_load((APP_DIR / "pvc.yaml").read_text())
        self.assertEqual(pvc["metadata"]["annotations"]["kustomize.toolkit.fluxcd.io/prune"], "disabled")
        self.assertEqual(pvc["metadata"]["labels"]["recurring-job-group.longhorn.io/weekly-backup"], "enabled")
        self.assertEqual(pvc["spec"]["storageClassName"], "longhorn-encrypted")
        self.assertNotIn("volumeName", pvc["spec"])


if __name__ == "__main__":
    unittest.main()
