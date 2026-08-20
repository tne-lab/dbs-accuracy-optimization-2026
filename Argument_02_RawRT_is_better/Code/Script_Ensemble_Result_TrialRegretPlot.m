%% --- 1. SETUP & CONFIGURATION ---
% Explicitly targeting the Days-based datasets for Day 7
fileConfigs = {'Results_NewXBaseline.mat', 'X-Baseline Condition';
               'Results_NewRawRT.mat', 'Raw RT Condition'};

algosToPlot = ["noalgorithm","greedy","egreedy","UCB","UCBbay","bernoulli",...
               "Poisson","Normal","bothNormal","UCBTemp025","UCBTemp075",...
               "UCBTuned","FVTS","MTS","NewNormal","NewFVTS","NewUCBBayes"];

% High-Contrast Professional Palette (Exact mapping)
cMap = [0.00, 0.45, 0.74; 0.85, 0.33, 0.10; 0.93, 0.69, 0.13; 
        0.49, 0.18, 0.56; 0.47, 0.67, 0.19; 0.30, 0.75, 0.93; 
        0.64, 0.08, 0.18; 0.25, 0.25, 0.25; 0.00, 0.50, 0.00; 
        1.00, 0.41, 0.16; 0.75, 0.00, 0.75; 0.50, 0.50, 0.00; 
        0.00, 0.00, 0.50; 0.20, 0.80, 0.20; 0.60, 0.40, 0.20; 
        0.40, 0.40, 0.40; 0.10, 0.10, 0.10];

targetDay = 'Day7'; 

%% --- 2. GENERATE NON-OVERLAPPING COMPARISON PLOT ---
fig = figure('Color', 'w', 'Position', [30, 30, 1850, 950]);
t = tiledlayout(1, 2, 'TileSpacing', 'Compact', 'Padding', 'Normal');
title(t, 'Algorithm Trial level regret (Day 7)', 'FontSize', 32, 'FontWeight', 'bold');

for f = 1:2
    if ~exist(fileConfigs{f,1}, 'file'), continue; end
    dataLoad = load(fileConfigs{f,1});
    res = dataLoad.results_accumulator;
    
    ax = nexttile; hold on; grid on; box on;
    set(ax, 'FontSize', 15, 'LineWidth', 1.6, 'GridAlpha', 0.08, 'TickDir', 'out');
    
    % --- SUCCESS ZONE SHADING ---
    % Note: Trial count usually defaults to 600 for these daily sets
    temp_nTrials = 600; 
    patch([0 temp_nTrials temp_nTrials 0], [0 0 10 10], [0.46 0.67 0.18], ...
          'EdgeColor', 'none', 'FaceAlpha', 0.1);
    yline(0, 'k-', 'LineWidth', 1.5, 'Alpha', 0.4);
    
    labelData = struct('y_actual', {}, 'y_display', {}, 'name', {}, 'color', {});
    count = 0;
    
    for a_idx = 1:length(algosToPlot)
        algoName = char(algosToPlot(a_idx));
        
        % Check if algorithm and specific day exist in the dataset
        if isfield(res, algoName) && isfield(res.(algoName).Day, targetDay)
            curve = res.(algoName).Day.(targetDay).Trial_Param_Regret_Mean_Curve;
            if isempty(curve), continue; end
            
            count = count + 1;
            curveMS = curve(:) * 1000; % Convert to ms
            current_nTrials = length(curveMS);
            thisCol = cMap(mod(a_idx-1, size(cMap,1))+1, :);
            
            % Plot the staircase trajectory
            stairs(curveMS, 'LineWidth', 2.2, 'Color', thisCol);
            
            labelData(count).y_actual = curveMS(end);
            labelData(count).name = strrep(algoName, '_', '\_');
            labelData(count).color = thisCol;
            labelData(count).nTrials = current_nTrials;
        end
    end
    
    % --- REFINED LABEL DE-CONFLATION ALGORITHM ---
    if ~isempty(labelData)
        % Use the trial length of the first valid algorithm for X-axis positioning
        finalTrial = labelData(1).nTrials; 
        
        % Sort by actual final regret
        [~, sIdx] = sort([labelData.y_actual]);
        labelData = labelData(sIdx);
        
        % Initialize display positions
        y_disp = [labelData.y_actual];
        min_gap = 2.8; % Minimum 2.8ms vertical gap between text baselines
        
        % Multi-pass iterative pushing to resolve overlaps
        for iter = 1:100 
            for k = 2:length(y_disp)
                overlap = min_gap - (y_disp(k) - y_disp(k-1));
                if overlap > 0
                    y_disp(k) = y_disp(k) + overlap/2;
                    y_disp(k-1) = y_disp(k-1) - overlap/2;
                end
            end
            % Keep within axis bounds
            y_disp(y_disp < 0) = 0;
            y_disp(y_disp > 70) = 70;
        end
        
        % Draw labels and high-visibility leader lines
        labelXStart = finalTrial * 1.03;
        for k = 1:length(labelData)
            % Leader Line: Solid, faint, connects end of data to adjusted text position
            line([finalTrial, labelXStart-(finalTrial*0.02)], [labelData(k).y_actual, y_disp(k)], ...
                 'Color', [labelData(k).color, 0.5], 'LineWidth', 1.2, 'HandleVisibility', 'off');
            
            % Bold Algorithm Text
            text(labelXStart, y_disp(k), labelData(k).name, ...
                'Color', labelData(k).color * 0.8, 'FontSize', 10, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', 'Clipping', 'off');
        end
    end
    
    % --- FORMATTING & LIMITS ---
    title(fileConfigs{f,2}, 'FontSize', 24, 'FontWeight', 'bold');
    xlabel('Trial Number \rightarrow', 'FontWeight', 'bold', 'FontSize', 16);
    
    if f == 1
        ylabel({'\leftarrow Performance Gap (Regret) in ms', 'Mean Distance from -70ms Optimal Target'}, ...
            'FontWeight', 'bold', 'FontSize', 17);
    end
    
    ylim([-2, 70]); 
    xlim([0, finalTrial * 1.2]); % Wide margin to prevent text clipping
    set(ax, 'YTick', 0:10:70);
    
    % Interpretive Callouts
    text(finalTrial*0.05, 67, '\uparrow High Information Loss', 'FontSize', 10, 'Color', [0.6 0.2 0.2], 'FontAngle', 'italic');
    text(finalTrial*0.05, 3, '\downarrow Target Achieved', 'FontSize', 10, 'Color', [0.2 0.5 0.2], 'FontAngle', 'italic');
end