# AWS provider reference

Two import paths:
- `alchemy/aws` — curated set (Lambda, DDB, S3, SQS, IAM, VPC, SES).
- `alchemy/aws-control` — auto-generated CloudFormation-style superset for everything else.

Auth: standard env (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`) or `AWS_PROFILE`. Use SSO/IAM Identity Center when possible — never commit long-lived keys.

## Curated examples

```ts
import { Function, Table, Bucket, Queue, Role, Policy } from "alchemy/aws";
import alchemy from "alchemy";

const role = await Role("lambda-role", {
  assumeRolePolicy: {
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Principal: { Service: "lambda.amazonaws.com" },
      Action: "sts:AssumeRole",
    }],
  },
});

const table = await Table("users", {
  partitionKey: { name: "pk", type: "S" },
  billingMode: "PAY_PER_REQUEST",
});

const bucket = await Bucket("uploads", { versioning: true });

const fn = await Function("handler", {
  role,
  runtime: "nodejs22.x",
  bundle: { entry: "./src/lambda.ts" },
  environment: {
    TABLE_NAME: table.name,
    BUCKET:     bucket.name,
    API_KEY:    alchemy.secret(process.env.API_KEY),
  },
});
```

## Networking

`Vpc`, `Subnet`, `InternetGateway`, `NatGateway`, `RouteTable`, `Route`, `SecurityGroup`, `SecurityGroupRule`.

## S3 state backend

```ts
import { S3StateStore } from "alchemy/aws";
const app = await alchemy("my-app", {
  stateStore: (scope) => new S3StateStore(scope, {
    bucketName: "my-app-alchemy-state",
    region: "us-east-1",
  }),
});
```
The bucket must exist beforehand. Recommended: enable versioning + SSE on the bucket.

## aws-control (CloudFormation-style)

Use for anything not in the curated set (Synthetics canaries, Cost Anomaly Monitors, Bedrock agents, etc). Import path mirrors the service:

```ts
import { Canary } from "alchemy/aws-control/synthetics";
```

API shape is one-to-one with CloudFormation properties.
