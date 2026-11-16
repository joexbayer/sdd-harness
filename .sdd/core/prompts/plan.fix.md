Fix: reproduce the bug first. Under "## Tasks" the first task is the regression test (`expect: fail`,
failing for the bug's reason), the next fixes the code. A bug that no test can show: start "## Test" with `none: <why>` and skip the regression task.

