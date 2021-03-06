# Return Calculation
# Zhongnan Fang
# June 30, 2016

#################################### Data cleaning ####################################
library(zoo)
library(tidyr)
library(dplyr)
options(scipen=50)
setwd("C:/Users/Chandler/Desktop/PPC/Data")

### Generate the dataframe of rawdata and clean the format
stock.df <- read.csv("RawData_all.csv", header = TRUE)
stock.df <-subset(stock.df, select = c("Date","SICCD","TICKER","PRC","RET","SHROUT"))
stock.df$date_Q <- as.yearqtr(as.character(stock.df$Date),format = "%m/%d/%Y")
stock.df$MKT <- stock.df$PRC*stock.df$SHROUT
stock.df$R <- 1 + as.numeric(as.character(stock.df$RET))

# Import the stock industry data
industry.df <- read.csv("industry.csv",header = TRUE)
stock.df <- merge(stock.df, industry.df, by = "TICKER")

# Filter all stock data from the watchlist
stock_list <- list(read.csv("stock_list.csv",header=TRUE))[[1]]
stock.df <- stock.df[(stock.df$TICKER %in% stock_list[,]),]

# drop all space and na data
stock.df <- stock.df[!(is.na(stock.df$R)|is.na(stock.df$TICKER)),]

# Generate quarterly calculation dataframe
stock_Q <- aggregate(stock.df$R,by=list(TICKER = stock.df$TICKER,date_Q = stock.df$date_Q, Industry = stock.df$Industry.Sector),FUN = prod)
MKT_Q <- aggregate(stock.df$MKT,by=list(TICKER = stock.df$TICKER,date_Q = stock.df$date_Q, Industry = stock.df$Industry.Sector),FUN = mean)

# Save the clean data into Rdata file
save(stock.df,industry.df,stock_Q, MKT_Q, stock_list, file="./stock_new.Rdata")
load("stock_new.Rdata")

#################################### Return Calculation ####################################
### Generate return dataframe 
return_Q <- spread(stock_Q,date_Q,x)
n <- names(return_Q)[-c(3:11)]
n_for_weight <- names(return_Q)[-c(3:10,54)]
return_Q <- return_Q[,n]
colnames(return_Q) <- make.names(colnames(return_Q), unique=TRUE)

### Generate weighting matrix -> from 2004Q4
Weight_Q <- spread(MKT_Q,date_Q,x)
Weight_Q <- Weight_Q[,n_for_weight]
colnames(Weight_Q) <- make.names(colnames(Weight_Q), unique=TRUE)


### get wired data
# wired.stock.df <- stock.df[stock.df$R>1.1 | stock.df$R<0.9,]
# write.csv(wired.stock.df,file='wired_stock_df.csv')

### Consider rebalance
# Get the rebalance table
rebalance_Q <- read.csv("rebalance_Q.csv",header = TRUE,check.names=FALSE)
rebalance_Q <- rebalance_Q[(rebalance_Q$Ticker %in% return_Q$TICKER),] # get the common of rebalance_Q and return_Q
return_Q <- return_Q[(return_Q$TICKER %in% rebalance_Q$Ticker),] # get the common of rebalance_Q and return_Q
rebalance_Q <- rebalance_Q[order(rebalance_Q[,1]),] # sort the ticker and make sure it is the same as return_Q

# Filter out all stocks that are in the watchlist
watchList_return_Q <- return_Q[0:nrow(return_Q),]
for (i in (0:(length(return_Q)-3))){
  watchList_return_Q[,i+3] <- rebalance_Q[,i+2]*return_Q[,i+3]
}
watchList_return_Q[is.na(watchList_return_Q)] <- 0

### Calcualate equal weight return
# Borrow the table structure from the return_Q
equal_weight_return_Q <- return_Q[0:2,-1:-2]
for (j in (0:(length(equal_weight_return_Q)-1))){
  equal_weight_return_Q[2,j+1] <- sum(watchList_return_Q[,j+3]>0)
  equal_weight_return_Q[1,j+1] <- sum(watchList_return_Q[,j+3])/equal_weight_return_Q[2,j+1]
}
equal_weight_return_Q <- data.frame(t(equal_weight_return_Q))
equal_weight_return_Q$cumReturn <- cumprod(equal_weight_return_Q[,1])

### Calculate the market weight return
# Format the weight Q
Weight_Q <- Weight_Q[(Weight_Q$TICKER %in% rebalance_Q$Ticker),] # get the common of rebalance_Q and Weight_Q
Weight_Q[is.na(Weight_Q)] <- 0 # replace NA with 0

# Get the market cap weighting dataframe : This is the weight which is used to calculate the next perioed market weighted return
# I adjust the prior bias since we use the lag rebalance table * weight_Q
watchList_market_weight_Q <- Weight_Q[0:nrow(Weight_Q),]
for (i in (0:(length(Weight_Q)-3))){
  watchList_market_weight_Q[,i+3] <- rebalance_Q[,i+2]*Weight_Q[,i+3]
}
watchList_market_weight_Q[is.na(watchList_market_weight_Q)] <- 0

# Calculate the market weight return considering the watchlist market weight 
market_weight_return_Q <- return_Q[0:1,-1:-2]
for (j in (0:(length(market_weight_return_Q)-1))){
  market_weight_return_Q[1,j+1] <- sum(watchList_return_Q[,j+3]*(watchList_market_weight_Q[,j+3]/sum(watchList_market_weight_Q[,j+3])))
}
market_weight_return_Q <- data.frame(t(market_weight_return_Q))
#market_weight_return_Q[1,1] <- 1 # Let 2005Q1 return equal to one since we skip the Q1 calculation, since we don't know the rebalance table of 2004 Q4
market_weight_return_Q$cumReturn <- cumprod(market_weight_return_Q[,1])

#################################### Russell Index ####################################
### Read Russell 2000 and clean the format
russell.df <- read.csv("Russell_index.csv", header = TRUE)
russell.df$date_Q <- as.yearqtr(as.character(russell.df$Date),format = "%m/%d/%Y")
russell.df[is.na(russell.df)] <- 0 # Set first return to be zero
russell.df$R <- russell.df$Return + 1

### Get Russell 2000 return_Q
russell_return_Q <- aggregate(russell.df$R,by=list(date_Q = russell.df$date_Q),FUN = prod)
russell_return_Q$cumReturn <- cumprod(russell_return_Q$x)
russell_return_Q <- russell_return_Q[1:44,]

### Read Russell 2000 by industry and clean the format
russell_industry.df <- read.csv("Russell_industry.csv", header = TRUE)
russell_industry.df$date_Q <- as.yearqtr(as.character(russell_industry.df$Date),format = "%m/%d/%Y")

# russell_industry_return <- russell_industry.df %>%
#   group_by(date_Q, Sector) %>%
#   sum





#################################### Industry Return Calculation ####################################
### Calculate return by industry
industry_return <- watchList_return_Q %>%
  gather(date_Q,Return,X2005.Q2:X2015.Q4) %>%
  group_by(date_Q,Industry) %>%
  filter(Return>0) %>%
  summarise(Return = mean(Return, na.rm=TRUE)) %>%
  spread(date_Q, Return)
industry_return[is.na(industry_return)] <- 0

### Calculate the weight of each industry in the watchlist
# Calculate the market value table
industry_mkt_weight <- watchList_market_weight_Q %>%
  gather(date_Q,MKT,X2005.Q1:X2015.Q3) %>% # 2015 Q4 is not available, since we don't know the next period rebalance table
  group_by(date_Q,Industry) %>%
  filter(MKT>0) %>%
  summarise(MKT = sum(MKT, na.rm=TRUE)) %>%
  spread(date_Q, MKT)
industry_mkt_weight[is.na(industry_mkt_weight)] <- 0

# Add Sum column
n <- nrow(industry_mkt_weight)
for (i in (1:(length(industry_mkt_weight)-1))){
  industry_mkt_weight[n+1,i+1] <- sum(industry_mkt_weight[1:n,i+1])
}

# Change the type of Industry Column
industry_mkt_weight$Industry <- as.character(industry_mkt_weight$Industry)

# Replace the NA value
industry_mkt_weight$Industry[is.na(industry_mkt_weight$Industry)] = 'Sum'

# Get the market value weight
industry_mkt_weight_percent<- industry_mkt_weight
for (i in (1:(length(industry_mkt_weight_percent)-1))){
  for (j in (1:(n+1))){
    industry_mkt_weight_percent[j,i+1] <- industry_mkt_weight[j,i+1]/industry_mkt_weight[n+1,i+1]
  }
}

#################################### Table Output ####################################
# write.csv(stock.df,file='stockdf.csv')
# write.csv(stock_Q,file='stock_Q.csv')
# write.csv(stock_M,file='stock_M.csv')
# write.csv(stock_list,file='stock_list.csv')
# write.csv(return_Q$TICKER,file="TICKER.csv")
# write.csv(rebalance_Q,file='rebalance.csv')
write.csv(return_Q,file='return_Q.csv')
write.csv(watchList_return_Q,file='watchList_return_Q.csv')
write.csv(equal_weight_return_Q,file='equal_weight_return_Q.csv')
write.csv(market_weight_return_Q,file='market_weight_return_Q.csv')


### Russell
write.csv(russell_return_Q, file = "russell_return_Q.csv")

### Industry of Watchlist
write.csv(industry_return,file='industry_return.csv')
# write.csv(industry_mkt_weight,file='industry_mkt_weight')
write.csv(industry_mkt_weight_percent,file='industry_mkt_weight_percent.csv')
