function testDataLabeled = prepareLabeledTestData(testData, testLabels)
%PREPARELABELEDTESTDATA Append binary labels as the final test-data variable.
nAssets = numel(testData);
testDataLabeled = cell(nAssets,1);
for k = 1:nAssets
    testDataLabeled{k} = addvars(testData{k},logical(testLabels{k}),NewVariableNames="AnomalyLabel");
end
end
