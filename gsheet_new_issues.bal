import ballerina/websub;
import ballerina/log;
import ballerinax/github.webhook;
import ballerinax/googleapis_sheets as sheets;

configurable string sheets_refreshToken = ?;
configurable string sheets_clientId = ?;
configurable string sheets_clientSecret = ?;
configurable string sheets_spreadSheetID = ?;
configurable string sheets_workSheetName = ?;

configurable string github_accessToken = ?;
configurable string github_callbackUrl = ?;
configurable string github_topic = ?;
configurable string github_secret = ?;


sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: {
        clientId: sheets_clientId,
        clientSecret: sheets_clientSecret,
        refreshUrl: sheets:REFRESH_URL,
        refreshToken: sheets_refreshToken
    }
};

sheets:Client spreadsheetClient = checkpanic new (spreadsheetConfig);

listener webhook:Listener githubListener = new (8080);

@websub:SubscriberServiceConfig {
    target: [webhook:HUB, github_topic],
    callback: github_callbackUrl,
    secret: github_secret,
    httpConfig: {
        auth: {
            token: github_accessToken
        }
    }
}
service websub:SubscriberService /subscriber on githubListener {
    remote function onEventNotification(websub:ContentDistributionMessage event) {
        final var headerValues = ["Issue Link", "Issue Number", "Issue Title", "Issue User", "Issue Creted At"];
        var headers = spreadsheetClient->getRow(sheets_spreadSheetID, sheets_workSheetName, 1);
        if(headers == []){
            error? appendResult = checkpanic spreadsheetClient->appendRowToSheet(sheets_spreadSheetID, sheets_workSheetName, 
                headerValues);
            if (appendResult is error) {
                log:printError(appendResult.message());
            }
        }
        var payload = githubListener.getEventType(event);
        if (payload is webhook:IssuesEvent) {
            if (payload.action == webhook:ISSUE_OPENED) {
                (string|int)[] values = [payload.issue.html_url, payload.issue.number, payload.issue.title, 
                    payload.issue.user.login, payload.issue.created_at];
                error? appendResult = checkpanic spreadsheetClient->appendRowToSheet(sheets_spreadSheetID, 
                    sheets_workSheetName, values);
                if (appendResult is error) {
                    log:printError(appendResult.message());
                }
            }
        }

    }
}
