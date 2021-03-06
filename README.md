# Functionbeat 7.4.2

Functionbeat is a beat implementation for a serverless architecture.
Addtional scripts have been added to support rapid configuration/deployment for FloSports' apps.
Logs are shipped to hosted ElasticSearch where they can be viewed in
[Kibana](https://4f95dc93e90e41f881de33d25141f8ac.us-west-2.aws.found.io:9243/)

## Usage (Only CloudWatch Logs ATM)

Build.sh takes three parameters.

1) The OS of the build (determines which compilation of functionbeat to run). Valid values are `osx` or `linux`
2) The beginning namespace of a serverless application. eg. `live-api-prod`
3) The ElasticSearch index prefix. eg. `app-x-nonprod`
4) An optional list of functions keywords to blacklist. eg. `"xlog|ylog|zlog`

### Application xyz-api in Dev

    # assuming no blacklist functions building from Jenkins
    ./build.sh linux xyz-api-dev xyz-api-nonprod

The build script will generate a functionbeat package for all logs in the namespace provided. If one already exists for that namespace, the function will be updated.

## TODO - Link to or Define Standard Log Format

## Documentation

For further information about functionbeat, see the
[Getting started](https://www.elastic.co/guide/en/beats/functionbeat/7.4/functionbeat-getting-started.html) guide.

Visit [Elastic.co Docs](https://www.elastic.co/guide/en/beats/functionbeat/7.4/index.html)
for the full Functionbeat documentation.

## Release notes

https://www.elastic.co/guide/en/beats/libbeat/7.4/release-notes-7.4.2.html
