This repository is a maintained mirror of “HOWTO: Building Apache and dependencies using CMake” from Apache Lounge (https://www.apachelounge.com/viewtopic.php?t=8609), with the necessary adjustments to support automated builds via GitHub Actions.

Key points:
- Source: Mirrors the original guide and batch script maintained by tangent on Apache Lounge.
- Purpose: Enable reproducible, automated Windows builds of Apache HTTP Server and its dependencies using CMake and NMake.
- Changes: Includes minimal edits required to run in CI, such as environment setup, path configuration, and non-interactive batch execution.
- CI: GitHub Actions workflows are provided to compile the full dependency stack and HTTPD using the versions and options outlined in the HOWTO.
