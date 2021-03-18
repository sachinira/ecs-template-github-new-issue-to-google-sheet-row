import ballerina/http;
import ballerina/websub;
import ballerinax/github.webhook;
import ballerinax/googleapis_sheets as sheets;


configurable string & readonly sheetId = ?;
configurable string & readonly workSheetName = ?;
configurable http:OAuth2DirectTokenConfig & readonly sheetOauthConfig = ?;
configurable string & readonly gitHubCallbackUrl = ?;
configurable string & readonly gitHubTopic = ?;
configurable int & readonly port = ?;
configurable http:BearerTokenConfig & readonly gitHubTokenConfig = ?;

sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: sheetOauthConfig
};
sheets:Client spreadsheetClient = check new (spreadsheetConfig);

listener webhook:Listener githubListener = new (port);

@websub:SubscriberServiceConfig {
    target: [webhook:HUB, gitHubTopic],
    callback: gitHubCallbackUrl,
    httpConfig: {
        auth: gitHubTokenConfig
    }
}
service / on githubListener {
    remote function onIssuesOpened(webhook:IssuesEvent event) returns error? {
        final var headerValues = [ISSUE_LINK, ISSUE_NUMBER, ISSUE_TITLE, ISSUE_USER, ISSUE_CREATED_AT];
        var headers = spreadsheetClient->getRow(sheetId, workSheetName, 1);
        if(headers == []){
            _ = check spreadsheetClient->appendRowToSheet(sheetId, workSheetName, headerValues);
        }

        (string|int)[] values = [event.issue.html_url, event.issue.number, event.issue.title, 
            event.issue.user.login, event.issue.created_at];
        _ = check spreadsheetClient->appendRowToSheet(sheetId, workSheetName, values);     
    }
}
