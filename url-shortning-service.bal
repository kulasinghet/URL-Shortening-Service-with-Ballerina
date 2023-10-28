import ballerina/http;
import ballerina/io;
import ballerina/time;
import ballerina/uuid;

// this is a url entry type in the database
type URLEntry readonly & record {
    readonly string id;
    string url;
};

// this is a url create dto
type URLCreateDTO readonly & record {
    string url;
};

// this is a table that holds url entries
table<URLEntry> key(id) urls = table [
    {id: "ads45s", url: "https://ballerina.io"},
    {id: "sdf45s", url: "https://ballerina.io/learn/api-docs/ballerina/http.html"},
    {id: "xyz123", url: "https://example.com"}
];

// http listner that listens to /urls
listener http:Listener HTTPListner = new (9090);

// service that handles / that would redirects to the original url
service / on HTTPListner {

    resource function get [string url]() returns http:Response|http:NotFound {

        io:println("URL: " + time:utcNow().toString() + " " + url); // Log the URL
        var urlEntry = urls[url];

        if (urlEntry is URLEntry) {
            io:print(url + " - " + urlEntry.url + "\n");
            return getResponse(urlEntry);
        }
        return (http:NOT_FOUND);
    }
}

// service that handles /api to add new urls to the database
service /api on HTTPListner {
    resource function post addURL(URLCreateDTO urlCreateDTO) returns http:Response {

        // Create a response
        http:Response response = new;

        // Validate the URL
        if (urlCreateDTO.url == "") {
            response.statusCode = 400; // 400 Bad Request
            response.setPayload("URL cannot be empty");
            return response;
        }

        // Validate the URL using a regex pattern
        // This regex pattern is taken from https://stackoverflow.com/a/3890175/12919712
        string:RegExp regex = re `((https?|ftp|smtp)://)?(www\.)?[a-zA-Z0-9]+(\.[a-z]{2,}){1,3}(\?[a-zA-Z0-9-_%]+=[a-zA-Z0-9-_%]+&?)*$`;

        if (!regex.isFullMatch(urlCreateDTO.url)) {
            response.statusCode = 400; // 400 Bad Request
            response.setPayload("Invalid URL");
            return response;
        }

        // Check if the URL already exists in the urls table
        foreach URLEntry urlentry in urls {
            if (urlentry.url === "http://" + urlCreateDTO.url) {
                response.statusCode = 200; // 200 OK
                response.setPayload(urlentry.toJson());
                return response;
            }
        }

        string id = generateRandomString();
        string url = "http://" + urlCreateDTO.url;

        if (id == "") {
            response.statusCode = 500; // 500 Internal Server Error
            response.setPayload("Error generating ID");
            return response;
        }

        // Create a new URLEntry record
        URLEntry urlEntry = {id: id, url: url};

        // Add the URL to the table
        urls.add(urlEntry);

        response.statusCode = 201; // 201 Created
        response.setPayload(urlEntry.toJson());

        return response;
    }

    // function that returns all the urls in the database
    resource function get getURLs() returns http:Response {
        http:Response response = new;
        response.statusCode = 200; // 200 OK
        response.setPayload(urls.toJson());
        return response;
    }

}

// function that accepts a url and creates a new http response that redirects to the url
function getResponse(URLEntry urlEntry) returns http:Response {
    http:Response response = new;
    response.statusCode = 302; // 302 status code indicates a temporary redirect
    response.setHeader("Location", urlEntry.url); // Set the location header to the URL
    return response;
}

// function that creates a six letter random string
function generateRandomString() returns string {
    string tempid = uuid:createType4AsString(); // Generate a random UUID
    return tempid.substring(0, 6); // Return the first 6 characters of the UUID
}
