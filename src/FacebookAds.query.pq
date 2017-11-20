// Use this file to write queries to test your data connector
let
    result = FacebookAds.API("/me/adaccounts",[fields="name"])[data]{0}
in
    result