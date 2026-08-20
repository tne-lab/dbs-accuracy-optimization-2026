%% ============================================================
% Pure Day 7 & Continuous Regret Plot (Aesthetic Polish)
% Single Axis | No-Box/No-Grid | Inward Ticks | Opaque Legend | Full Range Ticks
%% ============================================================
% Load the raw files
dataLoadEns = load('Results_NewRawRT.mat');
dataLoadCon = load('Results_Continuous_Accuracy_prob8_RawRT.mat');

% Pull the exact 4 structures you requested
ensBF  = dataLoadEns.results_accumulator.noalgorithm.Day.Day7.Trial_Param_Regret_Mean_Curve;
ensUCB = dataLoadEns.results_accumulator.UCB.Day.Day7.Trial_Param_Regret_Mean_Curve;
conBF  = dataLoadCon.results_accumulator.noalgorithm.Iterations.Iter4200.Trial_Param_Regret_Mean_Curve;
conUCB = dataLoadCon.results_accumulator.UCB.Iterations.Iter4200.Trial_Param_Regret_Mean_Curve;

% Setup crisp white figure canvas with controlled dimensions
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 650, 520]);
ax = axes('Parent', fig);
hold(ax, 'on');

% High-Contrast Academic Colors
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red

% Plot Continuous curves across the full range (1 to 4200)
p1 = stairs(ax, conBF  * 1000, 'LineWidth', 2.0, 'Color', [colorBF, 0.85],  'LineStyle', '-',  'DisplayName', 'BF - Continuous');
p2 = stairs(ax, conUCB * 1000, 'LineWidth', 2.0, 'Color', [colorUCB, 0.85], 'LineStyle', '-',  'DisplayName', 'UCB1 - Continuous');

% Plot Day 7 curves cleanly by supplying Y first, then shifting its timeline
p3 = stairs(ax, ensBF * 1000, 'LineWidth', 1.4, 'Color', [colorBF, 0.60], 'LineStyle', '-.', 'DisplayName', 'BF - Ensemble');
p4 = stairs(ax, ensUCB * 1000, 'LineWidth', 1.4, 'Color', [colorUCB, 0.60], 'LineStyle', '-.', 'DisplayName', 'UCB1 - Ensemble');

% Shift the Day 7 lines exactly to the last window of the 4200 trial timeline
day7_length = length(ensBF);
day7_start  = 4200 - day7_length + 1;
set(p3, 'XData', day7_start : 4200);
set(p4, 'XData', day7_start : 4200);

%% --- AESTHETIC GRAPH WRAPPING ---
box(ax, 'off'); 
grid(ax, 'off');  

% Handle limits smoothly based on your data peaks
all_curves = [conBF(:); conUCB(:); ensBF(:); ensUCB(:)] * 1000;
if ~isempty(all_curves)
    minY = min(all_curves); maxY = max(all_curves);
    ylim(ax, [floor(minY), ceil(maxY + (maxY - minY)*0.05)]);
end

% Lock X-Axis Limits to the complete 4200 trial timeline
xlim(ax, [0, 4200]);

% Exact custom X-axis ticks using your multiples of 600
set(ax, 'XTick', 0:600:4200);

% Labels and Fonts with TeX Interpreter for the Arrow
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% Clean bottom-left legend with an opaque white solid backdrop block
lgd = legend(ax, [p1, p2, p3, p4], 'Location', 'SouthWest', 'NumColumns', 1, 'FontSize', 11.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');

hold(ax, 'off');