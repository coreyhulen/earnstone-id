package com.earnstone.id;

import java.io.InputStream;
import java.util.Properties;

import com.sun.jersey.spi.container.servlet.ServletContainer;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;

import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;

@Path("/")
public class EidServer {
		
	private static Generator generator;
	private static Server server;

	@GET
	@Produces("text/html")
	public String getStatus() {		
		StringBuilder html = new StringBuilder();
		html.append("<html><body>");
		html.append("<h2>Earnstone Unique ID Generator</h2>");
		html.append("<ul>");
		html.append("<li>Data Center Id: ").append(generator.getDataCenterId()).append("</li>");
		html.append("<li>Wroker Id: ").append(generator.getWorkerId()).append("</li>");
		html.append("<li>Current timestamp: ").append(System.currentTimeMillis()).append("</li>");
		html.append("<li>Last timestamp: ").append(generator.getTimeStamp()).append("</li>");
		html.append("<li><a href='/nextId'>Get next Id</a></li>");
		html.append("</ul>");		
		html.append("</body></html>");
		return html.toString();		
	}

	@GET
	@Path("nextId")
	@Produces("text/plain")
	public String nextId() {
		return Long.toString(generator.nextId());
	}
	
	public synchronized static void initialize(Properties properties) throws Exception {		
		if (server == null) {
			System.out.println("EidServer Initializing");
									
			int port = Integer.parseInt(properties.getProperty("eid.server.port"));
			int dataCenterId = Integer.parseInt(properties.getProperty("eid.datacenter.id"));
			int workerId = Integer.parseInt(properties.getProperty("eid.worker.id"));			
			generator = new Generator(dataCenterId, workerId);		
			server = new Server(port);		

			ServletContextHandler context = new ServletContextHandler(ServletContextHandler.SESSIONS);
			context.setContextPath("/");
			server.setHandler(context);

			ServletHolder sh = new ServletHolder(ServletContainer.class);
			sh.setInitParameter("com.sun.jersey.config.property.resourceConfigClass", "com.sun.jersey.api.core.PackagesResourceConfig");
			sh.setInitParameter("com.sun.jersey.config.property.packages", "com.earnstone.id");
			context.addServlet(sh, "/*");
		}		
	}	
	
	public synchronized static void start() throws Exception {
		server.start();
		System.out.println("EidServer initialized and running");
	}
	
	public synchronized static void stop() throws Exception {
		server.stop();
		System.out.println("EidServer stopped");
		server = null;
		generator = null;				
	}	
		
	public static void main(String[] args) throws Exception {
		
		Properties properties = new Properties();			
		InputStream in = Thread.currentThread().getContextClassLoader().getResourceAsStream("eid.properties");
		if (in == null)
			throw new IllegalArgumentException("Couldn't find eid.properties resource.");
		properties.load(in);
		in.close();
		
		initialize(properties);
		start();		
		server.join();
	}	 
}
