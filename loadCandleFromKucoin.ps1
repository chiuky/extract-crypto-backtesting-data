[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $INPUT_TYPE = "1day", # type od the candle
    [Parameter()]
    [String]
    $INPUT_SYMBOL = "BTC-USDT", # currency pair  :BTC-USDT
    [Parameter()]
    [String]
    $INPUT_START_DATE = "2017-10-19", # start date in format like : 2020-01-01  YYYY-MM-DD
    [Parameter()]
    [String]
    $INPUT_END_DATE = "2024-02-22"  # end date in format like : 2020-01-01 YYYY-MM-DD
)
 
#FIRST RESULT for BTC-USDT START FROM EPOCH TIME : 1508307840 = Wednesday, October 18, 2017 6:24:00 AM

#https://www.kucoin.com/docs/rest/spot-trading/market-data/get-klines#http-request
#Param	Type	Mandatory	Description
#symbol	String	Yes	symbol
#startAt	long	No	Start time (second), default is 0
#endAt	long	No	End time (second), default is 0
#type	String	Yes	Type of candlestick patterns: 
# 1min, 3min, 5min, 15min, 30min, 
# 1hour, 2hour, 4hour, 6hour, 8hour, 12hour, 1day, 1week
#var math=require(Math)

#secInCandle : Example for 1day =  24 * 60 * 60 #hours in a day *min in a hour *sec in a min
if ($INPUT_TYPE -eq "1min") { $secInCandle = 60 }
elseif ($INPUT_TYPE -eq "3min") { $secInCandle = 3 * 60 }
elseif ($INPUT_TYPE -eq "5min") { $secInCandle = 5 * 60 }
elseif ($INPUT_TYPE -eq "15min") { $secInCandle = 15 * 60 }
elseif ($INPUT_TYPE -eq "30min") { $secInCandle = 30 * 60 }
elseif ($INPUT_TYPE -eq "1hour") { $secInCandle = 60 * 60 }
elseif ($INPUT_TYPE -eq "2hour") { $secInCandle = 2 * 60 * 60 }
elseif ($INPUT_TYPE -eq "4hour") { $secInCandle = 4 * 60 * 60 }
elseif ($INPUT_TYPE -eq "6hour") { $secInCandle = 6 * 60 * 60 }
elseif ($INPUT_TYPE -eq "8hour") { $secInCandle = 8 * 60 * 60 }
elseif ($INPUT_TYPE -eq "12hour") { $secInCandle = 12 * 60 * 60 }
elseif ($INPUT_TYPE -eq "1day") { $secInCandle = 24 * 60 * 60 }
elseif ($INPUT_TYPE -eq "1week" ) { $secInCandle = 7 * 24 * 60 * 60 } else {
    Write-Host "$INPUT_TYPE :  Not valid value !!! "
    exit #stop the script execution
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Cookie", "_cfuvid=NdTFhC5t5vLicVxJZ1_OWk0CRgbE6pIQVOewCyZmN2c-1706287202038-0-604800000; AWSALB=smd980yrlQhThjBKhYdX5sDWZ2jOtOKNKLn3BCpppNkJ7bdaBj8ureMOCk39vto5D0TZVDp0IUq1CkTa37BLz7IROyatS/hyYtWDilkjiWwlbKrckLkqlYU88IzJ; AWSALBCORS=smd980yrlQhThjBKhYdX5sDWZ2jOtOKNKLn3BCpppNkJ7bdaBj8ureMOCk39vto5D0TZVDp0IUq1CkTa37BLz7IROyatS/hyYtWDilkjiWwlbKrckLkqlYU88IzJ")


# .\getCandle.ps1 -INPUT_TYPE "15m"  -INPUT_SYMBOL "btc-usdt" -INPUT_START_DATE "2023-01-01"  -INPUT_END_DATE "2024-01-28"

$timeFormatSuffix = "T00:00:00";

$TYPE = $INPUT_TYPE;
$SYMBOL = $INPUT_SYMBOL;
$START_DATE = Get-Date -Date $INPUT_START_DATE$timeFormatSuffix -UFormat %s ;
$END_DATE = Get-Date -Date $INPUT_END_DATE$timeFormatSuffix  -UFormat %s ; #now
$FILE_NAME = "candles-for-backtesting-CANDLES_FROM_$($INPUT_START_DATE)_TO_$($INPUT_END_DATE)_$($TYPE)_$($SYMBOL).csv";

Write-Host "CANDLE_TYPE :" $TYPE
Write-Host "SYMBOL :" $SYMBOL
Write-Host "START_DATE :" $START_DATE
Write-Host "END_DATE :" $END_DATE
Write-Host "FILE_NAME :" $FILE_NAME



Write-Host "Seconds in 1 candle type($TYPE) = $secInCandle"
#calculate number of api call to execute
$responseSize = 1500 #max Candle returned by kucoin api invoked 
$stepSize = ($responseSize * $secInCandle)  # in seconds
[decimal] $iteration = ($END_DATE - $START_DATE) / $stepSize;

[decimal] $totalCandleToload = [math]::Floor(($END_DATE - $START_DATE) / $secInCandle)  #arrotondamento per difetto


$iteration = [math]::ceiling( $iteration) #arrotondamento all'intero successivo (quindi per eccesso)
#Write-Host $stepSize ;
Write-Host "API call required" $iteration

if ($iteration -lt 1) {
    $iteration++ #to manage small interval : <1500 candles(based on the candle type)
    $stepSize = [int]$END_DATE - [int]$START_DATE
}

'"TIMESTAMP", "OPEN", "CLOSE", "HIGH", "LOW", "VOLUME", "QUOTE_VOLUME", "CURRENCY_PAIR"' | Out-File $FILE_NAME;
for ($i = 0; $i -lt $iteration; $i++) {
    $END_DATE = [int]$START_DATE + [int]$stepSize;
   
    $apiUrl = "https://api.kucoin.com/api/v1/market/candles?type=$TYPE&symbol=$SYMBOL&startAt=$START_DATE&endAt=$END_DATE"
    Write-Host "apiUrl : " $apiUrl
    $response = Invoke-RestMethod   -Method 'GET' -Headers $headers  -Uri $apiUrl
    $jsonOut = $response | ConvertTo-Json
    $jqOut = $jsonOut | jq --arg SYMBOL "$SYMBOL" -r -c '.data[] | . + [$SYMBOL] | @csv' 
    $tacOut = $jqOut | tac $1 
    $tacOut >> $FILE_NAME ;
    
    $START_DATE = $END_DATE + $secInCandle;
    Write-Host "######"
    Write-Host  "API call #" $($i + 1) "/" $iteration
    $loadedCandles = (Get-Content $FILE_NAME).Length - 1; #CSV header to not be considered 
    Write-Host  "Candele caricate fin ora  : " $loadedCandles "/" $totalCandleToload
    if ($loadedCandles -lt $responseSize -and ($i + 1) -lt $iteration) {
        Write-Host "The api returned a number of candle smallest of the expeted , probably because does not contains all result for the requested interval"
        #$i=$iteration 
    }
}
