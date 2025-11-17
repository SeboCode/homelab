# Structure

Keep the structure simple!!! It should be understandable and easy to debug in a week, a month, a year, a decade (lol).
Do not try to avoid configuration duplication and splitting of configuration into secret/non-secret files. The duplication
that can be avoided this way is minimal, the complexity introduced into the setup is immense. It is not worth it.

The current structure is as follows:
| Filename | Description |
| :------- | :---------- |
| dev-secrets.yaml | Secrets used during the dev setup (e.g. DNS write token for the provided domain). |
| <node>-dev.yaml | Dev variables for node <node>. |
| prod.yaml | Production variables (including secrets) that stay the same for all nodes (e.g. DNS write token for the provided domain). |
| <node>.yaml | Production variables (including secrets) for node <node>. |
