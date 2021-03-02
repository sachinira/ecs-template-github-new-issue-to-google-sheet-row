import ballerina/http;
import ballerina/oauth2;
import ballerina/os;
import ballerina/websub;
import ballerinax/github.webhook as webhook;
import ballerinax/googleapis_sheets as sheets;

// Github listener new implementation is needed. 
oauth2:OutboundOAuth2Provider githubOAuth2Provider = new ({
    accessToken: os:getEnv("GH_ACCESS_TOKEN"),
    refreshConfig: {
        clientId: os:getEnv("GH_CLIENT_ID"),
        clientSecret: os:getEnv("GH_CLIENT_SECRET"),
        refreshUrl: os:getEnv("GH_REFRESH_URL"),
        refreshToken: os:getEnv("GH_REFRESH_TOKEN")
    }
});
http:BearerAuthHandler githubOAuth2Handler = new (githubOAuth2Provider);

listener webhook:Listener githubWebhookListener = new (4567);
//////////

sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshUrl: sheets:REFRESH_URL,
        refreshToken: refreshToken
    }
};

sheets:Client spreadsheetClient = checkpanic new (spreadsheetConfig);

@websub:SubscriberServiceConfig {
    subscribeOnStartUp: true,
    target: [webhook:HUB, "https://github.com/" + os:getEnv("GH_USERNAME") + "/" + os:getEnv("GH_REPO_NAME") 
        + "/events/*.json"],
    hubClientConfig: {
        auth: {
            authHandler: githubOAuth2Handler
        }
    },
    callback: os:getEnv("CALLBACK_URL")
}
service websub:SubscriberService /payload on githubWebhookListener {
    remote function onIssuesOpened(websub:Notification notification, webhook:IssuesEvent event) {
        (string|int)[] values = [event.issue.number, event.issue.title, event.issue.user.login, event.issue.created_at];

        error? append = checkpanic spreadsheetClient->appendRowToSheet(os:getEnv("SPREADSHEET_ID"), 
            os:getEnv("SPREADSHEET_NAME"), values);
    }
}
