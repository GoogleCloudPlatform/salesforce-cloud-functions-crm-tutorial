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
 * Invokes a GCP Cloud Function with new customer details.
 *
 * Invoked by the CustomerAccounts trigger when a new customer is added, this
 * class retrieves the service account keys from metadata storage, requests
 * an auth token, and calls an authenticated GCP Cloud Function with
 * the new customer account details.
 *
 * @author Google Inc.
 */
public class GCPManageCustomersService implements Queueable,
    Database.AllowsCallouts {

    // Serialised customer accounts
    private String serialisedAccs;

    // Action to be performed in GCP, can be 'create' customer account
    // in this example
    private String action;

    // Class to deserialise response from the Google token URL and get the
    // ID Token
    class GoogleAuthResponse {
        public String id_token;
    }

    // Class to construct the request body for the GCP Cloud Functions
    // callout
    class FunctionsRequest {
        public List<Account> customers;
        public String action;
    }

    public GCPManageCustomersService(String serialisedAccs, String action) {
        this.serialisedAccs = serialisedAccs;
        this.action = action;
    }

    /**
     * Invokes the GCP Cloud Function
     * @param token obtained from the authentication request
     * @param functionEndpoint of the GCP function to be called
     */
    @TestVisible
    private void updateCustomerMasterInGCP(String token,
        String functionEndpoint) {

        List<Account> deserialisedAccounts =
            (List<Account>)JSON.deserialize(
                serialisedAccs, List<Account>.class);

        FunctionsRequest requestMessage = new FunctionsRequest();
        requestMessage.customers = deserialisedAccounts;
        requestMessage.action = action;

        HTTP http = new HTTP();
        HTTPRequest req = new HTTPRequest();
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setEndpoint(functionEndpoint);
        req.setMethod('POST');
        req.setBody(JSON.serialize(requestMessage));
        HTTPResponse response=new HttpResponse();
        System.debug('POST request to ' + functionEndpoint);
        response = http.send(req);

        if (response.getStatusCode() == 200) {
            System.debug(functionEndpoint + ' called successfully');
        } else {
            System.debug(LoggingLevel.ERROR, 'Error occured ' +
                response.getStatus() + ' ' + response.getStatusCode());
        }
    }

    /**
     * Get GCP service account keys from metadata
     * @return the metadata record for the GCP service account
     */
    private GCP_Key__mdt getGCPServiceAccount() {
        List<GCP_Key__mdt> gcp_sa_keys = new List<GCP_Key__mdt>();
        gcp_sa_keys = [SELECT
            client_email__c,
            audience__c,
            token_endpoint__c
            FROM GCP_Key__mdt];

        if (gcp_sa_keys.size() > 0) {
            return gcp_sa_keys[0];
        } else {
            throw new GCPServiceAccountException('Cannot find GCP Service Account Keys');
        }
    }

    /**
     * Constructs the JWT and invokes the Google Auth endpoint
     * @param serviceAccount has the GCP keys obtained from the
     * custom metadata object
     * @return the auth response from GCP containing the id token
     */
    private GoogleAuthResponse getGCPAuthToken(GCP_Key__mdt serviceAccount) {

        GoogleAuthResponse result = new GoogleAuthResponse();

        Auth.JWT jwt = new Auth.JWT();
        jwt.setAud(serviceAccount.token_endpoint__c);
        jwt.setIss(serviceAccount.client_email__c);

        // Additional claims to set scope
        Map<String, Object> claims = new Map<String, Object>();
        claims.put('target_audience', serviceAccount.audience__c);
        jwt.setAdditionalClaims(claims);

        // Create the object that signs the JWT bearer token
        Auth.JWS jws = new Auth.JWS(jwt, 'google_cloud');

        // Get the resulting JWS in case debugging is required
        String token = jws.getCompactSerialization();

        // Set the token endpoint that the JWT bearer token is posted to
        String tokenEndpoint = serviceAccount.token_endpoint__c;

        Auth.JWTBearerTokenExchange bearer =
                new Auth.JWTBearerTokenExchange(tokenEndpoint, jws);

        if (!Test.isRunningTest()) {
            System.HttpResponse response = bearer.getHTTPResponse();

            result =
                (GoogleAuthResponse) JSON.deserialize(
                    response.getBody(), GoogleAuthResponse.class);
        } else {
            result.id_token = 'IN TEST';
        }

        return result;
    }


    /**
     * Process the new customer record(s)
     *
     * Called asynchronousely by Salesforce when customer(s) are added
     * @param context passed by the platform
     */
    public void execute(QueueableContext context) {

        GCP_Key__mdt serviceAccount = this.getGCPServiceAccount();
        GoogleAuthResponse authResponse = this.getGCPAuthToken(serviceAccount);

        if (authResponse.id_token != null) {
            // Call the Cloud Function
            this.updateCustomerMasterInGCP(
                authResponse.id_token, serviceAccount.audience__c);
        }
    }

    public class GCPServiceAccountException extends Exception {}
}