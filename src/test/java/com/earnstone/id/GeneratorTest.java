package com.earnstone.id;

import java.util.HashSet;

import junit.framework.Assert;

import org.junit.Test;

public class GeneratorTest {

	long workerMask = 0x000000000001F000L;
	long datacenterMask = 0x00000000003E0000L;
	long timestampMask = 0xFFFFFFFFFFC00000L;

	@Test
	public void generateAnId() {
		Generator gen = new Generator(1, 1);
		long id = gen.nextId();
		Assert.assertTrue(id > 0L);
	}

	@Test
	public void generateAccurateTimestamp() {
		Generator gen = new Generator(1, 1);
		long t = System.currentTimeMillis();
		Assert.assertTrue((gen.getTimeStamp() - t) < 50L);
	}

	@Test
	public void properlyMaskWorkerId() {
		long workerId = 0x1F;
		long datacenterId = 0;
		Generator gen = new Generator(datacenterId, workerId);

		for (int i = 0; i < 10000; i++) {
			long id = gen.nextId();
			Assert.assertTrue(((id & workerMask) >> 12) == workerId);
		}
	}

	@Test
	public void properlyMaskDataCenterId() {
		long workerId = 0;
		long datacenterId = 0x1F;
		Generator gen = new Generator(datacenterId, workerId);

		for (int i = 0; i < 10000; i++) {
			long id = gen.nextId();
			Assert.assertTrue(((id & datacenterMask) >> 17) == datacenterId);
		}
	}

	@Test
	public void properlyMaskTimestamp() {
		Generator gen = new Generator(31, 31);

		for (int i = 0; i < 10000; i++) {
			long t = System.currentTimeMillis() - Generator.twepoch;
			long id = gen.nextId();
			long t2 = (id & timestampMask) >> 22;
			Assert.assertTrue((t2 - t) >= 0 && (t2 - t) <= 20);
		}
	}

	@Test
	public void rollOverSequenceId() {
		// put a zero in the low bit so we can detect overflow from the sequence
		long workerId = 4;
		long datacenterId = 4;
		long startSequence = 0xFFFFFF - 20;
		Generator gen = new Generator(datacenterId, workerId, startSequence);

		for (int i = 0; i < 40; i++) {
			long id = gen.nextId();
			Assert.assertTrue(((id & workerMask) >> 12) == workerId);
		}
	}

	@Test
	public void generateIncreasingIds() {
		Generator gen = new Generator(1, 1);
		long lastId = 0L;
		for (int i = 0; i < 10000; i++) {
			long id = gen.nextId();
			Assert.assertTrue(id > lastId);
			lastId = id;
		}
	}

	@Test
	public void generate1MillionIdsQuickly() {
		Generator gen = new Generator(1, 1);
		long t = System.currentTimeMillis();

		for (int i = 0; i < 1000000; i++) {
			gen.nextId();
		}

		long t2 = System.currentTimeMillis();
		// extremely machine dependant (should take
		// less than .5 sec on a modern machine.
		Assert.assertTrue((t2 - t) < 5000);
	}

	@Test
	public void generateOnlyUniqueIds() {
		Generator gen = new Generator(31, 31);
		HashSet<Long> hset = new HashSet<Long>();

		for (int i = 0; i < 2000000; i++) {
			long id = gen.nextId();

			if (hset.contains(id)) {
				Assert.fail();
			}
			else {
				hset.add(id);
			}
		}
	}
}
