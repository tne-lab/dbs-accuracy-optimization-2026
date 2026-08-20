%% --- 1. SETUP & DATA LOADING ---
fileConfigs = {
    'Results_NewXBaseline.mat', 'X-Baseline ';
    'Results_NewRawRT.mat', 'Raw RT '; 
};

algos = ["noalgorithm","greedy","egreedy","UCB","UCBbay","UCBTuned",...
         "UCBTemp025","UCBTemp075","NewUCBBayes","bernoulli","Poisson",...
         "Normal","bothNormal","FVTS","MTS","NewNormal","NewFVTS"];

dayList = 1:7;
allData = cell(2, 1);
for f = 1:2
    if exist(fileConfigs{f,1}, 'file')
        temp = load(fileConfigs{f,1});
        allData{f} = temp.results_accumulator;
    end
end

%% --- 2. CALCULATE FIXED GLOBAL RANKING (Based on Raw RT) ---
% We use the Raw RT  (Index 2) to determine the "Master Order"
resRaw = allData{2};
masterPerformance = nan(length(algos), 1);

for aIdx = 1:length(algos)
    algo = char(algos(aIdx));
    if isfield(resRaw, algo)
        pld = 'Day'; if ~isfield(resRaw.(algo), pld), pld = 'Iterations'; end
        % We rank based on the Final Day performance in Raw RT
        dF = sprintf('Day%d', dayList(end));
        if isfield(resRaw.(algo).(pld), dF)
            masterPerformance(aIdx) = resRaw.(algo).(pld).(dF).Mean_Selection_accuracy(1);
        end
    end
end

% Create the sorted index once for both plots
[~, globalSortIdx] = sort(masterPerformance, 'descend', 'MissingPlacement', 'last');
sortedAlgos = algos(globalSortIdx);

%% --- 3. GENERATE SYNCHRONIZED HEATMAP ---
fig = figure('Color', 'w', 'Position', [50, 50, 1650, 950]);
t = tiledlayout(1, 2, 'TileSpacing', 'Compact', 'Padding', 'Normal');

for f = 1:2
    res = allData{f};
    % Re-extract data into the FIXED Master Order
    plotRawAcc = nan(length(sortedAlgos), length(dayList));
    
    for r = 1:length(sortedAlgos)
        algo = char(sortedAlgos(r));
        if ~isfield(res, algo), continue; end
        pld = 'Day'; if ~isfield(res.(algo), pld), pld = 'Iterations'; end
        for c = 1:length(dayList)
            dF = sprintf('Day%d', dayList(c));
            if isfield(res.(algo).(pld), dF)
                plotRawAcc(r, c) = res.(algo).(pld).(dF).Mean_Selection_accuracy(1);
            end
        end
    end
    
    % --- BASELINE CALCULATIONS (Relative to its own noalgorithm row) ---
    % Find the baseline row within the CURRENT dataset
    baseRowIdx = find(strcmp(sortedAlgos, "noalgorithm"));
    baselineValues = plotRawAcc(baseRowIdx, :);
    plotLift = plotRawAcc - baselineValues; 

    % --- PLOTTING ---
    ax = nexttile;
    imagesc(plotLift);
    hold on;
    
    colormap(ax, parula(256)); 
    cb = colorbar;
    ylabel(cb, 'Accuracy Lift vs. Baseline', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Synchronization: Use the same color scale for both plots
    % (Setting it to 0.3 ensures consistent color intensity between datasets)
    clim([-0.3, 0.3]); 
    
    % Visual Baseline Marker (Highlight the row that is the reference)
    yline(baseRowIdx - 0.5, 'w', 'LineWidth', 2.5);
    yline(baseRowIdx + 0.5, 'w', 'LineWidth', 2.5);
    
    % --- FORMATTING ---
    set(ax, 'YTick', 1:length(sortedAlgos), 'YTickLabel', strrep(sortedAlgos,'_','\_'), ...
        'XTick', 1:length(dayList), 'XTickLabel', dayList, ...
        'FontSize', 10, 'FontWeight', 'bold'); % Increased size for presentation
    
    title(fileConfigs{f,2}, 'FontSize', 24, 'FontWeight', 'bold');
    xlabel('Ensemble Number (Days)', 'FontSize', 20, 'FontWeight', 'bold');
    
    % Text Overlay (Bold Black Accuracy Values)
    for r = 1:size(plotRawAcc, 1)
        for c = 1:size(plotRawAcc, 2)
            if ~isnan(plotRawAcc(r,c))
                text(c, r, sprintf('%.2f', plotRawAcc(r,c)), ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 13, ...
                    'FontWeight', 'bold', ...
                    'Color', 'k'); 
            end
        end
    end
end

% Global Title
title(t, 'Accuracy: Raw RT vs. X-Baseline (Ranked by Raw RT Final Day)', ...
    'FontSize', 20, 'FontWeight', 'bold');



%% --- 4. STANDALONE FIGURE: PERFORMANCE DIFFERENCE (Raw RT vs. X-Baseline) ---
% Extract both datasets into fixed matrices based on the MASTER RANKING
resX = allData{1};
resR = allData{2};

accX = nan(length(sortedAlgos), length(dayList));
accR = nan(length(sortedAlgos), length(dayList));

for r = 1:length(sortedAlgos)
    algo = char(sortedAlgos(r));
    % Extract X-Baseline
    if isfield(resX, algo)
        pldX = 'Day'; if ~isfield(resX.(algo), pldX), pldX = 'Iterations'; end
        for c = 1:length(dayList)
            dF = sprintf('Day%d', dayList(c));
            if isfield(resX.(algo).(pldX), dF)
                accX(r, c) = resX.(algo).(pldX).(dF).Mean_Selection_accuracy(1); 
            end
        end
    end
    % Extract Raw RT
    if isfield(resR, algo)
        pldR = 'Day'; if ~isfield(resR.(algo), pldR), pldR = 'Iterations'; end
        for c = 1:length(dayList)
            dF = sprintf('Day%d', dayList(c));
            if isfield(resR.(algo).(pldR), dF)
                accR(r, c) = resR.(algo).(pldR).(dF).Mean_Selection_accuracy(1); 
            end
        end
    end
end

% Calculate Delta (Improvement)
accDiff = accR - accX;
baseRowIdx = find(strcmp(sortedAlgos, "noalgorithm"));

% Create Figure
figDiff = figure('Color', 'w', 'Position', [100, 100, 950, 950], 'Name', 'Raw RT Advantage Map');
axDiff = axes('Parent', figDiff);
hold(axDiff, 'on');

% Plot Difference Map
imagesc(axDiff, accDiff);
set(axDiff, 'YDir', 'reverse'); % CRITICAL: Matches the "Top-Down" ranking of the main plot

% Standard Parula colormap (Matches previous plots)
colormap(axDiff, parula(256));
cb = colorbar;
ylabel(cb, 'Accuracy Improvement (\Delta Accuracy)', 'FontSize', 14, 'FontWeight', 'bold');

% Center colorbar at 0
maxVal = max(abs(accDiff(:)), [], 'omitnan');
if isempty(maxVal) || maxVal == 0, maxVal = 0.1; end
clim(axDiff, [-maxVal, maxVal]); 

% Visual Baseline Marker (consistent white lines)
yline(axDiff, baseRowIdx - 0.5, 'w', 'LineWidth', 3);
yline(axDiff, baseRowIdx + 0.5, 'w', 'LineWidth', 3);

% Formatting (Synced with Main Plot)
set(axDiff, 'YTick', 1:length(sortedAlgos), 'YTickLabel', strrep(sortedAlgos,'_','\_'), ...
    'XTick', 1:length(dayList), 'XTickLabel', dayList, ...
    'FontSize', 10, 'FontWeight', 'bold', 'TickLabelInterpreter', 'none');

title(axDiff, {'Raw RT Performance Advantage', '(Raw RT Accuracy - X-Baseline Accuracy)'}, ...
    'FontSize', 22, 'FontWeight', 'bold');
xlabel(axDiff, 'Ensemble Number (Days)', 'FontSize', 18, 'FontWeight', 'bold');
ylabel(axDiff, 'Algorithms (Ranked by Raw RT Final Performance)', 'FontSize', 18, 'FontWeight', 'bold');

% Overlay Difference Values (Bold Black)
for r = 1:size(accDiff, 1)
    for c = 1:size(accDiff, 2)
        if ~isnan(accDiff(r,c))
            val = accDiff(r,c);
            txt = sprintf('%.2f', val);
            if val > 0, txt = ['+', txt]; end 
            
            text(c, r, txt, 'HorizontalAlignment', 'center', ...
                'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k'); 
        end
    end
end

grid(axDiff, 'off');
box(axDiff, 'on');