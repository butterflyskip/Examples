
library('ROCR')
library('ggplot2')
#library('vtreat') # not released yet, supplies designTreatmentsC() and prepare()


# example data load from https://github.com/WinVector/zmPDSwR/tree/master/PUMS
# load('phsample.RData')
# annotations <- c("ORIGFILEROWNUMBER","ORIGFILENAME","ORIGINSERTTIME","ORIGRANDGROUP")
# ignore <- c("RT","SERIALNO","SPORDER","RELP")
# hcols <- setdiff(colnames(dhus)[-grep('WGTP',colnames(dhus))],c(annotations,ignore))
# pcols <- setdiff(colnames(dpus)[-grep('PWGTP',colnames(dpus))],c(annotations,ignore))
# 
# # NOT done yet, need to force variables to be factors
# 
# # Categoric example on person data
# dYName <- 'hasInsurance'
# dpus[,dYName] <- (dpus$HICOV==1)
# pvars <- setdiff(pcols,c(dYName,'HINS1','HINS2','HINS3',
#                          'HINS4','HINS5','HINS6','HINS7',
#                          'HICOV','PRIVCOV','PUBCOV'))
# numericVars <- c('PINCP','AGEP','PERNP')
# for(v in setdiff(pvars,numericVars)) {
#   dpus[,v] <- as.factor(dpus[,v])
# }
# dTrainC <- subset(dpus,ORIGRANDGROUP>=100)
# dTestC <- subset(dpus,ORIGRANDGROUP<100)
# modelVars <- c('PINCP','PUMA','AGEP','OCCP')
# treatmentsC <- designTreatmentsC(dTrainC,modelVars,dYName,TRUE)
# dTrainCTreated <- prepare(treatmentsC,dTrainC)
# cvars <- setdiff(colnames(dTrainCTreated),dYName)
# dTestCTreated <- prepare(treatmentsC,dTestC)

load('healthInsExample.rData')

plotROC <- function(predcol,outcol) {
  perf <- performance(prediction(predcol,outcol),'tpr','fpr')
  pf <- data.frame(
    FalsePositiveRate=perf@x.values[[1]],
    TruePositiveRate=perf@y.values[[1]])
  plot=ggplot() +
    geom_ribbon(data=pf,aes(x=FalsePositiveRate,ymax=TruePositiveRate,ymin=0),
                fill='blue',alpha=0.3) +
    geom_point(data=pf,aes(x=FalsePositiveRate,y=TruePositiveRate)) +
    geom_line(aes(x=c(0,1),y=c(0,1)))
  list(pf=pf,plot=plot)
}

vars1 <- setdiff(cvars,c('PUMA_catN','PUMA_lev_100','PUMA_lev_300','PUMA_lev_800','AGEP_clean'))
model1 <- glm(paste(dYName,paste(vars1,collapse=' + '),sep=' ~ '),data=dTrainCTreated,
    family=binomial(link='logit'))
dTestCTreated$pred1 <- predict(model1,newdata=dTestCTreated,type='response')
ggplot(data=dTestCTreated) + geom_density(aes_string(x='pred1',color=dYName))
eval1 <- prediction(dTestCTreated$pred1,dTestCTreated[,dYName])
pl1 <- plotROC(dTestCTreated$pred1,dTestCTreated[,dYName])
print(pl1$plot)
auc1 <- attributes(performance(eval1,'auc'))$y.values[[1]]
print(auc1)

confusion1 <- table(truth=dTestCTreated[,dYName],pred=dTestCTreated$pred1>=0.75)
print(confusion1)
print(confusion1/sum(confusion1))

S <- 0
truth <- dTestCTreated[,dYName]
pred <- dTestCTreated$pred1
deviance = -2*(sum(ifelse(truth,log(pred),log(1-pred)))-S)
print(deviance)
## [1] 487.3445


plotThreshDoubleDense <- function(truth,pred,yname) {
  dPos <- density(pred[truth])
  pd2pos <- data.frame(pred=dPos$x,density=dPos$y)
  pd2pos[,yname] <- TRUE
  dNeg <- density(pred[!truth])
  pd2neg <- data.frame(pred=dNeg$x,density=dNeg$y)
  pd2neg[,yname] <- FALSE
  pd2 <- rbind(pd2pos,pd2neg)
  ggplot(data=pd2) +
    geom_line(aes_string(x='pred',y='density',color=yname)) +
    geom_vline(xintercept=0.75) +
    geom_ribbon(data=pd2[pd2[,yname] & pd2$pred<=0.75,],aes(x=pred,ymax=density,ymin=0),alpha=0.3) +
    geom_ribbon(data=pd2[(!pd2[,yname]) & pd2$pred>=0.75,],aes(x=pred,ymax=density,ymin=0),alpha=0.3) +
    facet_wrap(as.formula(paste('~',yname)),ncol=1)
}

plotThreshDoubleDense(dTestCTreated[,dYName],dTestCTreated[,'pred1'],dYName)



model2 <- glm(paste(dYName,paste(cvars,collapse=' + '),sep=' ~ '),data=dTrainCTreated,
              family=binomial(link='logit'))
dTestCTreated$pred2 <- predict(model2,newdata=dTestCTreated,type='response')
ggplot(data=dTestCTreated) + geom_density(aes_string(x='pred2',color=dYName))
eval2 <- prediction(dTestCTreated$pred2,dTestCTreated[,dYName])
pl2 <- plotROC(dTestCTreated$pred2,dTestCTreated[,dYName])
print(pl2$plot)
auc2 <- attributes(performance(eval2,'auc'))$y.values[[1]]
print(auc2)


pl1$pf$what <- 'model1'
pl2$pf$what <- 'model2'
pf <- rbind(pl1$pf,pl2$pf)
ggplot() +
  geom_line(data=pf,aes(x=FalsePositiveRate,y=TruePositiveRate,color=what)) +
  geom_point(data=pf,aes(x=FalsePositiveRate,y=TruePositiveRate,color=what)) +
  geom_line(aes(x=c(0,1),y=c(0,1)))

# save(list=ls(),file='healthInsExample.rData')
