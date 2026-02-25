# image-builder-vmware

Image builder for Cluster API VMware. Required for automatically creating OS images with the latest OS patches and pre-installed Kubernetes.

## Requirements

* Written for GitLab CI
* Internet connection is required for the GitLab Runner. If you want to use the GitLab Runner through a proxy, please see the information in the [image-builder book](https://image-builder.sigs.k8s.io/)
* Please use your own CI_IMAGE (see file cicd/.gitlab-ci-template.yml)

## CI/CD variables

The following CI/CD variables are required:

* *CI_REGISTRY* – your private/public registry
* *VC_CAPV_PASSWORD* – password for the user with required permissions for Cluster API in VMware
* *VC_CAPV_ADMIN* – admin password for the Cluster API user

## Run

* Can be run on a schedule (e.g., monthly)
* Creates the current OS image template
* Renames the previous template by adding the suffix -<year>-<previous-month>
* Keeps the last 3 templates

## Contribition

Please feel free to contribute to the project! :)
