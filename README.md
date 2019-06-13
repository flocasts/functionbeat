# Functionbeat 7.1.1

Functionbeat is a beat implementation for a serverless architecture.
Addtional scripts have been added to support rapid configuration/deployment for FloSports' apps.
Logs are shipped to hosted ElasticSearch where they can be viewed in
[Kibana](https://elk.flocasts.biz)

## Usage (Only CloudWatch Logs ATM)

Build.sh takes three parameters.

1) The beginning namespace of a serverless application. eg. `live-api-prod`
2) The action to be performed. `deploy`, `update`, `remove`
3) An optional list of functions keywords to blacklist. eg. `"kinda-broken|mega-broken|doesnt-even-log"`*

\* If a function logs nothing, it _has_ to be part of the blacklist

Given hardset policy limitations in AWS Lambda, each application will have one log processor per 40 functions.

### Application xyz-api in Dev

    # assuming no blacklist functions
    ./build.sh xyz-api-dev deploy

This will build out a set of log-processors depending on the number of application functions to be monitored.

Subsequently, each new build of xyz-api-<env> should kick off a downstream job to continue updating the log-processors. If no new functions are added or removed, functionbeat will recognize that and no action will be taken.

    ./build.sh xyz-api-dev update

## TODO - Link to or Define Standard Log Format

## Documentation

For further information about functionbeat, see the
[Getting started](https://www.elastic.co/guide/en/beats/functionbeat/7.1/functionbeat-getting-started.html) guide.

Visit [Elastic.co Docs](https://www.elastic.co/guide/en/beats/functionbeat/7.1/index.html)
for the full Functionbeat documentation.

## Release notes

https://www.elastic.co/guide/en/beats/libbeat/7.1/release-notes-7.1.1.html
