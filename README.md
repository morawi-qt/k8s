# k8s
This repository composed of the kubernetes components. It will be changed on regular bases. 
To install the components you must follow this path

1.config<p>
2.gateway<p>
3.license<p>
4.read<p>
5.write<p>
6.echo<p>
7.state<p>
8.search<p>
9.balance<p>
10.rabbitmq<p>
11.zipkin<p>
12.eth<p>
13.xrp<p>
14.xbt<p>
  
  
### SMEE for GitHub + Jenkins Auth

Use the CLI
```
$ npm install --global smee-client
```
Then the smee command will forward webhooks from smee.io to your local development environment.
The url below is specific to us:
```
$ smee -u https://smee.io/bK3oxson2b5T4ny
```
For usage info:
```
$ smee --help
```
Use the Node.js client
```
$ npm install --save smee-client
```

Then:
```
const SmeeClient = require('smee-client')

const smee = new SmeeClient({
  source: 'https://smee.io/bK3oxson2b5T4ny',
  target: 'http://localhost:3000/events',
  logger: console
})

const events = smee.start()

// Stop forwarding events
events.close()
```
Using Probot's built-in support
```
$ npm install --save smee-client

```
Then set the environment variable:
```
WEBHOOK_PROXY_URL=https://smee.io/bK3oxson2b5T4ny
```
