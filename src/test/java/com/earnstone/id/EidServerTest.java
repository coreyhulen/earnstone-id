package com.earnstone.id;

import java.util.Properties;

import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.BeforeClass;
import org.junit.Test;

import com.sun.jersey.api.client.Client;
import com.sun.jersey.api.client.WebResource;

public class EidServerTest {

	private static long workerId = 0;
	private static long dataCenterId = 0;
	private static long workerMask = 0x000000000001F000L;
	private static long datacenterMask = 0x00000000003E0000L;

	@BeforeClass
	public static void setup() throws Exception {
		Properties properties = new Properties();
		properties.setProperty("eid.server.port", "43120");
		properties.setProperty("eid.datacenter.id", Long.toString(workerId));
		properties.setProperty("eid.worker.id", Long.toString(dataCenterId));
		EidServer.initialize(properties);
		EidServer.start();
	}

	@AfterClass
	public static void teardown() throws Exception {
		EidServer.stop();
	}

	@Test
	public void restfulNextId() {
		Client c = Client.create();
		WebResource r = c.resource("http://localhost:43120/nextId");
		String idStr = r.get(String.class);
		long id = Long.parseLong(idStr);
		Assert.assertTrue(id > 0);
	}

	@Test
	public void properlyMaskWorkerId() {

		Client c = Client.create();
		WebResource r = c.resource("http://localhost:43120/nextId");

		for (int i = 0; i < 2000; i++) {
			String idStr = r.get(String.class);
			long id = Long.parseLong(idStr);
			Assert.assertTrue(((id & workerMask) >> 12) == workerId);
		}
	}

	@Test
	public void properlyMaskDataCenterId() {
		Client c = Client.create();
		WebResource r = c.resource("http://localhost:43120/nextId");

		for (int i = 0; i < 2000; i++) {
			String idStr = r.get(String.class);
			long id = Long.parseLong(idStr);
			Assert.assertTrue(((id & datacenterMask) >> 17) == dataCenterId);
		}
	}

	@Test
	public void serverInfo() {
		Client c = Client.create();
		WebResource r = c.resource("http://localhost:43120/");
		String html = r.get(String.class);
		Assert.assertTrue(html != null && html.length() > 0);
	}
}
