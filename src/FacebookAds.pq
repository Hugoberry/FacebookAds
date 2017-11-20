// This file contains your Data Connector logic
section FacebookAds;

app_secret = Extension.LoadString("AppSecret");
app_id = Extension.LoadString("AppId");
redirectUrl = "https://preview.powerbi.com/views/oauthredirect.html";
windowWidth = 720;
windowHeight = 1024;

[DataSource.Kind="FacebookAds", Publish="FacebookAds.Publish"]
shared FacebookAds.Campaigns = (optional url as text, optional params as record) =>
    let
        key = Extension.CurrentCredential()[access_token],
        accountRequest = Web.Contents("https://graph.facebook.com/v2.11/me/adaccounts?"&Uri.BuildQueryString([access_token=key,fields="name"])),
        adaccounts = Json.Document(accountRequest)[data],
        out = UserToNavTabler(adaccounts)

    in
        out;

[DataSource.Kind="FacebookAds"]
shared FacebookAds.API = (optional url as text, optional params as record) =>
    let
        key = Extension.CurrentCredential()[access_token],
        allParams = if params=null then [access_token=key] else [access_token=key]&params,
        apiRequest = Web.Contents("https://graph.facebook.com/v2.11"&url&"?"&Uri.BuildQueryString(allParams)),
        out = Json.Document(apiRequest)
    in
        out;

UserToNavTabler = (users as list) =>
    let
        navCol = {"Name","Key","Data","ItemKind", "ItemName", "IsLeaf"}, 
        navRow = List.Accumulate(users,{},(s,c)=>s&{{c[name],c[id],GetAccountCampaignsInsights(c),"Table","Table",true}} ),
        objects = #table(navCol,navRow),
        out = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        out;

GetAccountCampaignsInsights = (adaccount) =>
    let
        key = Extension.CurrentCredential()[access_token],
        campaignsReq = Web.Contents("https://graph.facebook.com/v2.11/"&adaccount[id]&"/campaigns?"&Uri.BuildQueryString([access_token=key,fields="name"])),
        campaigns=Json.Document(campaignsReq)[data],
        out = List.Accumulate(campaigns,#table(null,{}),(s,c)=>s&GetCampaignInsights(c))
    in
        out;

GetCampaignInsights = (campaign) =>
    let 
        key = Extension.CurrentCredential()[access_token],
        insights = Web.Contents("https://graph.facebook.com/v2.11/"&campaign[id]&"/insights?"&Uri.BuildQueryString([access_token=key,fields="total_actions,reach,impressions,frequency,unique_clicks,spend"])),
        res = Json.Document(insights)[data],
        out = if res={} then campaign else campaign&res{0}
    in
        Table.FromRecords({out});

// Data Source Kind description
FacebookAds = [
    Authentication = [
        
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
FacebookAds.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = FacebookAds.Icons,
    SourceTypeImage = FacebookAds.Icons
];

FacebookAds.Icons = [
    Icon16 = { Extension.Contents("FacebookAds16.png"), Extension.Contents("FacebookAds20.png"), Extension.Contents("FacebookAds24.png"), Extension.Contents("FacebookAds32.png") },
    Icon32 = { Extension.Contents("FacebookAds32.png"), Extension.Contents("FacebookAds40.png"), Extension.Contents("FacebookAds48.png"), Extension.Contents("FacebookAds64.png") }
];

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://www.facebook.com/v2.11/dialog/oauth?" & Uri.BuildQueryString([
            client_id = app_id,
            redirect_uri = redirectUrl,
            scope="ads_read"])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirectUrl,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod(parts[code])
    in
        result;

TokenMethod = (code) =>
    let
        response = Web.Contents("https://graph.facebook.com/v2.11/oauth/access_token?" & Uri.BuildQueryString([
                client_id = app_id,
                redirect_uri = redirectUrl,
                client_secret = app_secret,
                code = code]),
            [ManualStatusHandling = {400}]),
        body = Json.Document(response),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;