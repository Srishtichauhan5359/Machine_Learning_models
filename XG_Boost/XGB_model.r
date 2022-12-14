require(caret)
require(e1071)
require(dplyr)
require(xgboost)
require(data.table)
require(Matrix)
require(ROCR)
data$admit <- as.factor(data$admit)
ind <- sample(1:nrow(data), round(0.70*nrow(data)))
train <- as.data.frame(data[ind,])
test <- as.data.frame(data[-ind,])
str(test)
setDT(train)
labels <- train$admit
labels_ts <- test$admit
new_tr <- model.matrix(~.+0, data = train[,-c("admit"),with=F])
new_ts <- model.matrix(~.+0, data = test[,-c("admit"), with=F])
labels <- as.numeric(labels)-1
labels_ts <- as.numeric(labels_ts)-1
dtrain <- xgb.DMatrix(data = new_tr,label = labels)
dtest <- xgb.DMatrix(data = new_ts,label=labels_ts)
parameters <- list(booster = "gbtree", objective = "binary:logistic", eta=0.5, gamma=0.5, max_depth=2, 
min_child_weight=1, subsample=1, colsample_bytree=1)
xgb_cross_val <- xgb.cv( params = parameters, data = dtrain, nrounds = 100, nfold = 5, showsd = T, 
stratified = T, print_every_n = 5, early_stop_round = 5, maximize = F, verbose=T, eval_metric = 'auc', 
prediction = T )
require(pROC)
jpeg('XGB_training_Five_fold_CV.jpg')
plot(pROC::roc(response = labels, predictor = xgb_cross_val$pred, levels=c(0, 1)), lwd=1.5, 
main="ROC Curve for 5 fold CV", print.cutoffs.at=seq(0, 1, by=0.05), text.adj=c(-0.5, 0.5), 
text.cex=0.5)
dev.off()
xgb_model <- xgb.train (params = parameters, data = dtrain, nrounds = 1000, watchlist = list(val=dtest, 
train=dtrain), print_every_n =5, early_stop_round = 5, maximize = F , eval_metric = "auc", prediction 
= T)
xgbpred_tr <- predict (xgb_model, dtrain)
xgbpred_tr <- ifelse (xgbpred_tr > 0.5,1,0)
xgbpred_tr <- as.factor(xgbpred_tr)
tr_label <- as.factor(labels)
conf_matrix_training <- confusionMatrix (xgbpred_tr, tr_label)
xgbpred <- predict (xgb_model,dtest)
xgbpred <- ifelse (xgbpred > 0.5,1,0)
xgbpred <- as.factor(xgbpred)
ts_label <- as.factor(labels_ts)
conf_matrix_testing <-confusionMatrix (xgbpred, ts_label)
jpeg('XGB_training_important_varables.jpg')
model <- xgb.dump(xgb_model, with_stats=TRUE)
names <- dimnames(dtrain)[[2]]
importance_matrix <- xgb.importance(names, model=xgb_model)[0:30]
xgb.plot.importance(importance_matrix)
dev.off()
jpeg('XGB_training_AUC.jpg')
prediction_for_AUC_tr <- predict(xgb_model, dtrain)
xgb_pred_for_auc_tr <- prediction(prediction_for_AUC_tr, tr_label)
xgb_perf_for_auc_tr <- performance(xgb_pred_for_auc_tr, "tpr", "fpr")
plot( xgb_perf_for_auc_tr, avg="threshold", colorize=TRUE, lwd=1, main="ROC Curve for training 
model", print.cutoffs.at=seq(0, 1, by=0.05), text.adj=c(-0.5, 0.5), text.cex=0.5)
dev.off()
jpeg('XGB_internal_test_AUC.jpg')
prediction_for_AUC <- predict(xgb_model, dtest)
xgb_pred_for_auc <- prediction(prediction_for_AUC, ts_label)
xgb_perf_for_auc <- performance(xgb_pred_for_auc, "tpr", "fpr")
plot( xgb_perf_for_auc, avg="threshold", colorize=TRUE, lwd=1, main="ROC Curve for internal test", 
print.cutoffs.at=seq(0, 1, by=0.05), text.adj=c(-0.5, 0.5), text.cex=0.5)
dev.off()
