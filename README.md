# Welcome to Functionbeat 7.1.1

Functionbeat is a beat implementation for a serverless architecture.

## Getting Started

To get started with Functionbeat, you need to set up Elasticsearch on
your localhost first. After that, start Functionbeat with:

     ./functionbeat -c functionbeat.yml -e

This will start Functionbeat and send the data to your Elasticsearch
instance. To load the dashboards for Functionbeat into Kibana, run:

    ./functionbeat setup -e

For further steps visit the
[Getting started](https://www.elastic.co/guide/en/beats/functionbeat/7.1/functionbeat-getting-started.html) guide.

## Documentation

Visit [Elastic.co Docs](https://www.elastic.co/guide/en/beats/functionbeat/7.1/index.html)
for the full Functionbeat documentation.

## Release notes

https://www.elastic.co/guide/en/beats/libbeat/7.1/release-notes-7.1.1.html
