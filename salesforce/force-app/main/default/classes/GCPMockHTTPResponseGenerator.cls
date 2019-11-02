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
 * This class generates a mock response for the HTTP callout made from the
 * test class called GCPManageCustomersServiceTest
 *
 * @author Google Inc.
 */
@isTest
global class GCPMockHTTPResponseGenerator implements HttpCalloutMock {

    public boolean methodCalled = false;

    global HTTPResponse respond(HTTPRequest req) {

        System.assertEquals('POST', req.getMethod());
        System.assertEquals('application/json', req.getHeader('Content-Type'));

        methodCalled = true;

        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"status":"Done"}');
        res.setStatusCode(200);
        return res;
    }
}