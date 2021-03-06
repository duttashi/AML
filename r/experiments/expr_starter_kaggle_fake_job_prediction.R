
# objective: To identify fake job posting
# data source: Kaggle
# load required libraries
library(tidyverse) 
library(caret) 

# load data

df_train<- read.csv("kaggle_fake_job_prediction/data/fake_job_postings.csv", header = TRUE,sep = ",", stringsAsFactors = FALSE)
# make a copy
df<- df_train

# coerce multiple character vars to factor
df<- df %>%
  mutate_if(is.character, funs(factor(.)))
# replace empty factor levels with NA
find_empty_level<- which(levels(df$employment_type)=="")
levels(df$employment_type)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$location)=="")
levels(df$location)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$department)=="")
levels(df$department)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$salary_range)=="")
levels(df$salary_range)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$company_profile)=="")
levels(df$company_profile)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$salary_range)=="")
levels(df$salary_range)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$requirements)=="")
levels(df$requirements)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$employment_type)=="")
levels(df$employment_type)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$employment_type)=="")
levels(df$employment_type)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$required_experience)=="")
levels(df$required_experience)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$required_education)=="")
levels(df$required_education)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$industry)=="")
levels(df$industry)[find_empty_level]<-"NA"
find_empty_level<- which(levels(df$function.)=="")
levels(df$function.)[find_empty_level]<-"NA"

# coerce target var to factor
df$fraudulent<- factor(df$fraudulent)
# recode the target class var levels to something meaningful else there is an error when building models
levels(df$fraudulent)<- c("not_fake","fake")

# coerce vars to factor
df$telecommuting<- factor(df$telecommuting)
df$has_company_logo<- factor(df$has_company_logo)
df$has_questions<- factor(df$has_questions)

# check and impute missing values
colSums(is.na(df))

# Visualize the imbalanced data
table(df$fraudulent) # 866 fake job postings
df %>%
  ggplot(aes(x=fraudulent))+
  geom_bar()+
  ggtitle("Imbalanced class distribution")+
  labs(x="fraudulent", y="failure count")+
  theme_bw()+
  theme(panel.border = element_rect(colour = "black", fill=NA, size=1))

###### PREDICTIVE MODELLING ON IMBALANCED TRAINING DATA

# keep only relevant factor vars 
names(df)
df.1<- df[,c(1,10:15,17:18)]
str(df.1)
# Run algorithms using 3-fold cross validation
set.seed(2020)
index <- createDataPartition(df.1$fraudulent, p = 0.7, list = FALSE, times = 1)
train_data <- df.1[index, ]
test_data  <- df.1[-index, ]
# create caret trainControl object to control the number of cross-validations performed
ctrl <- trainControl(method = "repeatedcv",
                     number = 3,
                     # repeated 3 times
                     repeats = 3, 
                     verboseIter = FALSE, 
                     classProbs=TRUE, 
                     summaryFunction=twoClassSummary
                     )

# Metric is AUPRC which is Area Under Precision Recall Curve (PRC). Its more robust then using ROC. Accuracy and Kappa are used for balanced classes, while PRC is used for imbalanced classes
set.seed(2020)
# turning "warnings" off
options(warn=-1)
metric <- "AUPRC"

# CART
set.seed(2020)
fit_cart<-caret::train(fraudulent ~ .,data = train_data,
                       method = "rpart",
                       preProcess = c("scale", "center"),
                       trControl = ctrl 
                       ,metric= "ROC"
                       )


# Logistic Regression
set.seed(2020)
fit_glm<-caret::train(fraudulent ~ .,data = train_data
                      , method = "glm", family = "binomial"
                      , preProcess = c("scale", "center")
                      , trControl = ctrl
                      , metric= "ROC"
                      )
# summarize accuracy of models
models <- resamples(list(cart=fit_cart, glm=fit_glm))
summary(models) # sensitivity of cart is maximum
# compare accuracy of models
dotplot(models)
bwplot(models)

# Make Predictions using the best model
predictions <- predict(fit_cart, test_data)
confusionMatrix(predictions, test_data$fraudulent) # 67% balanced accuracy with kappa at 0.50

# PREDICTIVE MODELLING On BALANCED DATA
# Method 1: Under Sampling
set.seed(2020)
ctrl <- trainControl(method = "repeatedcv",
                     number = 3,
                     # repeated 3 times
                     repeats = 3, 
                     verboseIter = FALSE, 
                     classProbs=TRUE, 
                     summaryFunction=twoClassSummary,
                     sampling = "down"
                     )
fit_under<-caret::train(fraudulent ~ .,data = train_data,
                        method = "rpart",
                        preProcess = c("scale", "center"),
                        trControl = ctrl 
                        ,metric= "ROC"
                        )

# Method 2: Over Sampling
set.seed(2020)
ctrl <- trainControl(method = "repeatedcv",
                     number = 3,
                     # repeated 3 times
                     repeats = 3, 
                     verboseIter = FALSE, 
                     classProbs=TRUE, 
                     summaryFunction=twoClassSummary,
                     sampling = "up"
                     )

fit_over<-caret::train(fraudulent ~ .,data = train_data,
                       method = "rpart",
                       preProcess = c("scale", "center"),
                       trControl = ctrl 
                       ,metric= "ROC"
                       )
# summarize accuracy of models
models <- resamples(list(rpart_under=fit_under, rpart_over=fit_over))
summary(models) # highest sensistivity is for over sampling
# compare accuracy of models
dotplot(models)
bwplot(models)

# Make Predictions using the best model
predictions <- predict(fit_over, test_data)
# Using under-balancing as a method for balancing the data
confusionMatrix(predictions, test_data$fraudulent) # 87% accuracy on balanced under sampled logistic regression model
