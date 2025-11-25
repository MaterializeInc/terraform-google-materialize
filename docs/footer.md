## Connecting to Materialize instances

Access to the database is through the balancerd pods on:
* Port 6875 for SQL connections.
* Port 6876 for HTTP(S) connections.

Access to the web console is through the console pods on port 8080.

#### TLS support

TLS support is provided by using `cert-manager` and a self-signed `ClusterIssuer`.

More advanced TLS support using user-provided CAs or per-Materialize `Issuer`s are out of scope for this Terraform module. Please refer to the [cert-manager documentation](https://cert-manager.io/docs/configuration/) for detailed guidance on more advanced usage.

## Upgrade Notes

#### v0.7.0

This is an intermediate version to handle some changes that must be applied in stages.
It is recommended to upgrade to v0.8.x after upgrading to this version.

Breaking changes:
* Swap is enabled by default.
* Support for lgalloc, our legacy spill to disk mechanism, is deprecated, and will be removed in the next version.
* We now always use two node groups, one for system workloads and one for Materialize workloads.
    * Variables for configuring these node groups have been renamed, so they may be configured separately.

To avoid downtime when upgrading to future versions, you must perform a rollout at this version.
1. Ensure your `environmentd_version` is at least `v26.0.0`.
2. Update your `request_rollout` (and `force_rollout` if already at the correct `environmentd_version`).
3. Run `terraform apply`.

You must upgrade to at least v0.6.x before upgrading to v0.7.0 of this terraform code.

It is strongly recommended to have enabled swap on v0.6.x before upgrading to v0.7.0 or higher.

#### v0.6.1

We now have some initial support for swap.

We recommend upgrading to at least v0.5.10 before upgrading to v0.6.x of this terraform code.

To use swap:
1. Set `swap_enabled` to `true`.
2. Ensure your `environmentd_version` is at least `v26.0.0`.
3. Update your `request_rollout` (and `force_rollout` if already at the correct `environmentd_version`).
4. Run `terraform apply`.

This will create a new node group configured for swap, and migrate your clusterd pods there.


#### v0.6.0

This version is missing the updated helm chart.
Skip this version, go to v0.6.1.

#### v0.3.0

We now install `cert-manager` and configure a self-signed `ClusterIssuer` by default.

Due to limitations in Terraform, it cannot plan Kubernetes resources using CRDs that do not exist yet. We have worked around this for new users by only generating the certificate resources when creating Materialize instances that use them, which also cannot be created on the first run.

For existing users upgrading Materialize instances not previously configured for TLS:
1. Leave `install_cert_manager` at its default of `true`.
2. Set `use_self_signed_cluster_issuer` to `false`.
3. Run `terraform apply`. This will install cert-manager and its CRDs.
4. Set `use_self_signed_cluster_issuer` back to `true` (the default).
5. Update the `request_rollout` field of the Materialize instance.
6. Run `terraform apply`. This will generate the certificates and configure your Materialize instance to use them.
