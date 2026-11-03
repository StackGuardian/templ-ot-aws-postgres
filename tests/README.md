# Tests

Tests use the built-in OpenTofu test framework (`tofu test`, OpenTofu 1.9 or later).

| Level | Folder | What it does | Cost | When it runs |
|---|---|---|---|---|
| Unit | `tests/unit` | Plan only with mocked providers. Checks configuration and security settings. | None | Merge requests into `development` or `main`, and tags |
| Integration | `tests/integration` | Deploys real resources, checks them, destroys them. | Cloud cost while running | Tags, when cloud credentials are set (`integration-tests` job) |

## Run locally

```bash
tofu init
tofu test -test-directory=tests/unit
tofu test -test-directory=tests/integration   # needs cloud credentials
```

## Test cases

| ID | Level | Description | Status |
|---|---|---|---|
| U-01 | Unit | Default variables produce a valid plan with all default tags | done |
| U-02 | Unit | Invalid `name_prefix` is rejected | done |
| U-03 | Unit | Custom `tags` are merged with the default tags | done |
| U-04 | Unit | DB instance is not publicly accessible and port 5432 is open only to the VPC | done |
| U-05 | Unit | Storage encryption is enabled | done |
| U-06 | Unit | Master password is managed by Secrets Manager, no password in code, secret ARN is an output | done |
| U-07 | Unit | Parameter group sets `rds.force_ssl = 1` and matches the major version | done |
| U-08 | Unit | Automated backups are enabled | done |
| U-09 | Unit | `backup_retention_days = 0` is rejected | done |
| U-10 | Unit | Database uses two private subnets in two AZs | done |
| U-11 | Unit | Log exports, enhanced monitoring and VPC flow logs are enabled | done |
| I-01 | Integration | DB instance status is `available` | done |
| I-02 | Integration | Endpoint resolves to private IPs inside the VPC | done |
| I-03 | Integration | Master password secret exists in Secrets Manager (value is not read) | done |

Integration tests are written but have not run against a real cloud account yet.
