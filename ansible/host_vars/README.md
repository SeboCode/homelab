# Structure

Keep the structure simple!!! It should be understandable and easy to debug in a week, a month, a year, a decade (lol).
Do not try to avoid configuration duplication and splitting of configuration into secret/non-secret files. The duplication
that can be avoided this way is minimal, the complexity introduced into the setup is immense. It is not worth it.

The current structure is as follows:
| Filename | Description |
| :------- | :---------- |
| <env>/shared-secrets.yaml | Secrets used during the setup of <env> environment for all nodes (e.g. DNS write token for the provided domain). |
| <env>/<node>.yaml | <env> variables (including secrets) for node <node>. |
