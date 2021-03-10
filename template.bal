import ballerina/websub;
import ballerinax/github.webhook;
import ballerinax/googleapis_sheets as sheets;

configurable string sheets_refresh_token = ?;
configurable string sheets_client_id = ?;
configurable string sheets_client_secret = ?;
configurable string sheets_spreadsheet_id = ?;
configurable string sheets_worksheet_name = ?;
configurable string github_access_token = ?;
configurable string github_callback_url = ?;
configurable string github_topic = ?;
configurable string github_secret = ?;

sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: {
        clientId: sheets_client_id,
        clientSecret: sheets_client_secret,
        refreshUrl: sheets:REFRESH_URL,
        refreshToken: sheets_refresh_token
    }
};
sheets:Client spreadsheetClient = check new (spreadsheetConfig);

listener webhook:Listener githubListener = new (8080);

@websub:SubscriberServiceConfig {
    target: [webhook:HUB, github_topic],
    callback: github_callback_url,
    secret: github_secret,
    httpConfig: {
        auth: {
            token: github_access_token
        }
    }
}
service websub:SubscriberService /subscriber on githubListener {
    remote function onEventNotification(websub:ContentDistributionMessage event) returns error? {
        final var headerValues = [ISSUE_LINK, ISSUE_NUMBER, ISSUE_TITLE, ISSUE_USER, ISSUE_CREATED_AT];
        var headers = spreadsheetClient->getRow(sheets_spreadsheet_id, sheets_worksheet_name, 1);
        if(headers == []){
            _ = check spreadsheetClient->appendRowToSheet(sheets_spreadsheet_id, sheets_worksheet_name, headerValues);
        }
        var payload = githubListener.getEventType(event);
        if (payload is webhook:IssuesEvent) {
            if (payload.action == webhook:ISSUE_OPENED) {
                (string|int)[] values = [payload.issue.html_url, payload.issue.number, payload.issue.title, 
                    payload.issue.user.login, payload.issue.created_at];
                _ = check spreadsheetClient->appendRowToSheet(sheets_spreadsheet_id, sheets_worksheet_name, values);
            }
        }

    }
}
