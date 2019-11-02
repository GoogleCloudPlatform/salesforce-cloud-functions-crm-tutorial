/*
 * Copyright 2019 Google LLC
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *     https://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * This test class invokes a mock endpoint to test the methods in the
 * GCPManageCustomerService class.
 *
 * @author Google Inc.
 */
@isTest
public class GCPManageCustomersServiceTest {
    static testmethod void testQueueable() {

        GCPMockHttpResponseGenerator mock = new GCPMockHttpResponseGenerator();

        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();

        List<Account> testCustomers = new List<Account>();
        testCustomers.add(new Account(name='Sample Customer Account'));
        insert testCustomers;

        Test.stopTest();

        List<AsyncApexJob> asyncJobList =
            [select id, ApexClass.Name, JobType, Status from AsyncApexJob];
        System.assertEquals(1, asyncJobList.size());
        System.assertEquals(true, mock.methodCalled);
    }
}