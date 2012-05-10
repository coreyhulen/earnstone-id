
# Earnstone Unique ID Generator

### Description
EID is a service for generating unique ID numbers at high scale with some 
simple guarantees (based on the work from https://github.com/twitter/snowflake).
The service can be in-memory or run as a REST-ful web service using Jetty.  The main
differences between Snowflake and EID are 

*   **Java vs Scala** - Our company uses Java.
*   **REST Server vs Thrift Server** - With a simple REST-ful interface
    we can access the service from anywhere without the need to generate thrift
    bindings.  We are willing to sacrifice raw speed for usability.  We are still able
    to generate 4K ids/sec per machine on our development hardware.  If speed is a 
    concern then look at using the in-memory version of EID.
*   **No Zookeeper dependency** - Zookeeper is great, but someone can mis-configure
    the Zookeeper location generating the same unqiue ids.  Removing the dependancy puts
    more responsibility on the person configuring the EID services.  So **be careful** 
    when configuring the data center and worker ids. 

### Download
[eid-0.3-all.zip](https://github.com/coreyhulen/blog/raw/master/eid-0.3-all.zip) 

### How to Use EID
Extract the files and start/stop the server using the following commands 

    Usage: server.sh [-d] {start|stop|run|restart|check|supervise} [ CONFIGS ... ] 
    $./bin/server.sh start
    $./bin/server.sh stop

To check on the server status or manually generate unique ids navigate to `http://localhost:43120`

Example of how to use the REST interface to generate remote ids
    
    // import com.sun.jersey.api.client.Client;
    // import com.sun.jersey.api.client.WebResource;
    Client c = Client.create();
    WebResource r = c.resource("http://localhost:43120/nextId");
    String idStr = r.get(String.class);
    long id = Long.parseLong(idStr);

For multi-machine configuration make sure to change the data center and worker ids 
located in ./config/eid.properties
