YOUR JOB in this run: write only the code and tests of the tasks above, nothing else.
{{name}} ticks these tasks for you when you stop, by running their tests, and the orchestrator
commits. So, overriding the steps above:
- Never edit the item file (the File: line above): {{name}} puts it back as it was.
- Never run `{{cmd}} task done`, and never commit.
- Run each command as written, from where you are: no `cd` in front of it.
