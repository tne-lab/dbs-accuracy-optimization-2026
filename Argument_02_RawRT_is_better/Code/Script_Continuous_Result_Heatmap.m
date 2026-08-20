
%% --- 1. SETUP & DATA LOADING ---
fileConfigs = {
    'Results_Continuous_Accuracy_prob8_RawRT.mat', 'Raw RT (Group Count) ';
    'Results_Continuous_Accuracy_prob8_RawRT.mat', 'Raw RT (Mean-Group Count-Global Mean) '; 
};

algos = ["noalgorithm","greedy","egreedy","UCB","UCBbay","UCBTuned",...
         "UCBTemp025","UCBTemp075","NewUCBBayes","bernoulli","Poisson",...
         "Normal","bothNormal","FVTS","MTS","NewNormal","NewFVTS"];

% NEW: Define your specific iteration list
iterationList = 600:600:4200; 

allData = cell(2, 1);
for f = 1:2
    if exist(fileConfigs{f,1}, 'file')
        temp = load(fileConfigs{f,1});
        allData{f} = temp.results_accumulator;
    end
end

%% --- 2. CALCULATE FIXED GLOBAL RANKING (Based on Raw RT) ---
resRaw = allData{2};
masterPerformance = nan(length(algos), 1);
for aIdx = 1:length(algos)
    algo = char(algos(aIdx));
    if isfield(resRaw, algo)
        % Using the final iteration for ranking
        lastIterField = sprintf('Iter%d', iterationList(end));
        if isfield(resRaw.(algo).Iterations, lastIterField)
            masterPerformance(aIdx) = resRaw.(algo).Iterations.(lastIterField).Mean_Selection_accuracy(1);
        end
    end
end
[~, globalSortIdx] = sort(masterPerformance, 'descend', 'MissingPlacement', 'last');
sortedAlgos = algos(globalSortIdx);

%% --- 3. GENERATE SYNCHRONIZED HEATMAP ---
fig = figure('Color', 'w', 'Position', [50, 50, 1650, 950]);
t = tiledlayout(1, 2, 'TileSpacing', 'Compact', 'Padding', 'Normal');

for f = 1:2
    res = allData{f};
    plotRawAcc = nan(length(sortedAlgos), length(iterationList));
    
    for r = 1:length(sortedAlgos)
        algo = char(sortedAlgos(r));
        if ~isfield(res, algo), continue; end
        
        for c = 1:length(iterationList)
            iterField = sprintf('Iter%d', iterationList(c));
            if isfield(res.(algo).Iterations, iterField)
                if f ==2
                    plotRawAcc(r, c) = sum(res.(algo).Iterations.(iterField).Mean_Selection_accuracy(1));
                else
                    plotRawAcc(r, c) = sum(res.(algo).Iterations.(iterField).Mean_Selection_accuracy_new(1));
                end
            end
        end
    end
    
    baseRowIdx = find(strcmp(sortedAlgos, "noalgorithm"));
    baselineValues = plotRawAcc(baseRowIdx, :);
    plotLift = plotRawAcc - baselineValues; 

    ax = nexttile;
    imagesc(plotLift); hold on;
    colormap(ax, parula(256)); 
    cb = colorbar;
    ylabel(cb, 'Accuracy Lift vs. Baseline', 'FontSize', 14, 'FontWeight', 'bold');
    % clim([-0.3, 0.3]); 
    
    yline(baseRowIdx - 0.5, 'w', 'LineWidth', 2.5);
    yline(baseRowIdx + 0.5, 'w', 'LineWidth', 2.5);
    
    set(ax, 'YTick', 1:length(sortedAlgos), 'YTickLabel', strrep(sortedAlgos,'_','\_'), ...
        'XTick', 1:length(iterationList), 'XTickLabel', iterationList, ...
        'FontSize', 10, 'FontWeight', 'bold');
    
    title(fileConfigs{f,2}, 'FontSize', 24, 'FontWeight', 'bold');
    xlabel('Optimization Iterations', 'FontSize', 14, 'FontWeight', 'bold');
    
    for r = 1:size(plotRawAcc, 1)
        for c = 1:size(plotRawAcc, 2)
            if ~isnan(plotRawAcc(r,c))
                text(c, r, sprintf('%.2f', plotRawAcc(r,c)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 13, ...
                    'FontWeight', 'bold', 'Color', 'k'); 
            end
        end
    end
end
title(t, 'Accuracy: Raw RT vs. X-Baseline (Ranked by Raw RT Final Iteration)', 'FontSize', 20, 'FontWeight', 'bold');

%% --- 4. STANDALONE FIGURE: PERFORMANCE DIFFERENCE ---
resX = allData{1};
resR = allData{2};
accX = nan(length(sortedAlgos), length(iterationList));
accR = nan(length(sortedAlgos), length(iterationList));

for r = 1:length(sortedAlgos)
    algo = char(sortedAlgos(r));
    for c = 1:length(iterationList)
        iterField = sprintf('Iter%d', iterationList(c));
        if isfield(resX, algo) && isfield(resX.(algo).Iterations, iterField)
            accX(r, c) = resX.(algo).Iterations.(iterField).Mean_Selection_accuracy(1); 
        end
        if isfield(resR, algo) && isfield(resR.(algo).Iterations, iterField)
            accR(r, c) = resR.(algo).Iterations.(iterField).Mean_Selection_accuracy(1); 
        end
    end
end

accDiff = accR - accX;
figDiff = figure('Color', 'w', 'Position', [100, 100, 950, 950], 'Name', 'Raw RT Advantage Map');
axDiff = axes('Parent', figDiff);
hold(axDiff, 'on');

imagesc(axDiff, accDiff);
set(axDiff, 'YDir', 'reverse'); 
colormap(axDiff, parula(256));
cb = colorbar;
ylabel(cb, 'Accuracy Improvement (\Delta Accuracy)', 'FontSize', 14, 'FontWeight', 'bold');

maxVal = max(abs(accDiff(:)), [], 'omitnan');
if isempty(maxVal) || maxVal == 0, maxVal = 0.1; end
% clim(axDiff, [-maxVal, maxVal]); 

yline(axDiff, baseRowIdx - 0.5, 'w', 'LineWidth', 3);
yline(axDiff, baseRowIdx + 0.5, 'w', 'LineWidth', 3);

set(axDiff, 'YTick', 1:length(sortedAlgos), 'YTickLabel', strrep(sortedAlgos,'_','\_'), ...
    'XTick', 1:length(iterationList), 'XTickLabel', iterationList, ...
    'FontSize', 10, 'FontWeight', 'bold', 'TickLabelInterpreter', 'none');

title(axDiff, {'Raw RT Performance Advantage', '(Raw RT Accuracy - X-Baseline Accuracy)'}, 'FontSize', 22, 'FontWeight', 'bold');
xlabel(axDiff, 'Optimization Iterations', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(axDiff, 'Algorithms (Ranked by Raw RT Final Performance)', 'FontSize', 18, 'FontWeight', 'bold');

for r = 1:size(accDiff, 1)
    for c = 1:size(accDiff, 2)
        if ~isnan(accDiff(r,c))
            val = accDiff(r,c);
            txt = sprintf('%.2f', val);
            if val > 0, txt = ['+', txt]; end 
            text(c, r, txt, 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k'); 
        end
    end
end
grid(axDiff, 'off'); box(axDiff, 'on');