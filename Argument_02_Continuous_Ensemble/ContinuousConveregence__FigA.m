%% ========================================================================
%  STANDALONE BASELINE TRAJECTORY PLOTTER (150:15:4200)
%  ========================================================================
clear; clc; close all;
tic;
for TotalIterations = 600:600:4200
% --- FILE PATH CONFIGURATION ---
baseline_root = 'I:\2026 Performance Improvment\Data\SensorChanging\ContinuedOverDaysOptimization\OptimizationBaseline\RawRT\Divisor15\probSize8';

algorithms = ["noalgorithm","greedy","egreedy","UCB","UCBbay","bernoulli","Poisson",...
"Normal","bothNormal","UCBTemp025","UCBTemp075","UCBTuned",...
"FVTS","MTS","NewNormal","NewFVTS","NewUCBBayes"];

TargetNumRuns   = 1000;
divisor = 15;
days = 1;

% Define the steps
trial_steps = 15:15:TotalIterations;
baseline_trajectories = zeros(length(algorithms), length(trial_steps));
baseline_trajectories_regret =  zeros(length(algorithms), TotalIterations);
fprintf('>>> EXTRACTING TRAJECTORIES FROM BASELINE FILES...\n');

for a_idx = 1:length(algorithms)
    algoStr = char(algorithms(a_idx));
    fileName = sprintf('%d%s1000.mat', TotalIterations, algoStr);
    baseline_file = fullfile(baseline_root, fileName);
    
    if exist(baseline_file, 'file')
        fprintf('Processing Baseline: %s\n', algoStr);
        bl_load = load(baseline_file, 'dat1');
        struct_name = strcat("dist_", algoStr, num2str(divisor));
        div_name = strcat("divisor", num2str(divisor));
        dt_baseline = bl_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
        
        % Loop through the timeline 
        parfor t_idx = 1:length(trial_steps)
            target_t = trial_steps(t_idx);
            % Use your exact function to pull accuracy at this milestone step
            [acc_vals_bl_tar, CombinedData, ~, ~] = calculate_accuracy_convergence_with_target(dt_baseline, days, TargetNumRuns, algorithms(a_idx), target_t);
            baseline_trajectories(a_idx, t_idx) = acc_vals_bl_tar(1) * 100; % Convert to percentage
        end
        Param_Trial_Regret_Mean_Curve = calculate_trial_level_regret_Mean_Curve(dt_baseline);
        baseline_trajectories_regret(a_idx, :)  = Param_Trial_Regret_Mean_Curve;
    else
        fprintf('WARNING: Missing file for %s\n', algoStr);
    end
end
save(strcat(num2str(TotalIterations),'_baseline_trajectories_results.mat'), 'baseline_trajectories', 'baseline_trajectories_regret', 'algorithms', 'trial_steps');
end
%% High-Contrast Bold Base Palette Style Definitions
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue (BF)
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red (UCB1)
    
% Controlled publication-grade window framework dimensions
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 650, 520]);
ax = axes('Parent', fig);
hold(ax, 'on');

% Plot Foreground Metrics (Continuous Focus — Solid Lines, No markers for smooth trajectory curves)
p1 = plot(ax, trial_steps, baseline_trajectories(1, :)/100, '-', ... 
    'Color', colorBF, 'LineWidth', 2.2, 'DisplayName', 'Brute Force (BF)');
p2 = plot(ax, trial_steps, baseline_trajectories(2, :)/100, '-', ... 
    'Color', colorUCB, 'LineWidth', 2.2, 'DisplayName', 'UCB1');

% ========================================================================
%  Axis Formatting, Limits & Typography
% ========================================================================
box(ax, 'off');   % Strip top and right border lines
grid(ax, 'off');  % Strip background grid lines

% Axis Limits 
xlim(ax, [150, 4200]);
ylim(ax, [0, 1]);

% Clean steps for the framework coordinates
yticks(ax, 0:0.2:1);
xticks(ax, [150, 600, 1200, 1800, 2400, 3000, 3600, 4200]);

% Labels matching your target figure geometry
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', 'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework Framework Elements
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% Clean Legend with Solid White Backdrop Block
lgd = legend(ax, [p1, p2], 'Location', 'SouthEast', 'NumColumns', 1, 'FontSize', 11.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');

hold(ax, 'off');
toc
%%
%% ========================================================================
%  STANDALONE INSTANTANEOUS MEAN REGRET PLOTTER (ALL ALGORITHMS)
%  ========================================================================

num_algos = length(algorithms);
TotalIterations = size(baseline_trajectories_regret, 2);
trials_full = 1:TotalIterations;

% --- High-Contrast Distinct Color Palette for 17 Algorithms ---
colors = lines(num_algos);
colors(1, :) = [0.0000, 0.2706, 0.4784]; % Brute Force (Navy Blue)
colors(4, :) = [0.8000, 0.1412, 0.1137]; % UCB (Crimson Red)

% --- Format Display Names for Legend ---
displayNames = algorithms;
displayNames(algorithms == "noalgorithm") = "Brute Force (BF)";

% --- Create Figure Framework ---
fig = figure('Name', 'Instantaneous Regret', 'Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 750, 550]);
ax = axes('Parent', fig);
hold(ax, 'on');

% --- Preallocate Graphic Handles Array ---
p_reg = gobjects(num_algos, 1); 

% --- Plot Continuous Trajectories ---
for a_idx = 1:num_algos
    p_reg(a_idx) = plot(ax, trials_full, baseline_trajectories_regret(a_idx, :), '-', ...
        'Color', colors(a_idx, :), 'LineWidth', 1.8, 'DisplayName', displayNames(a_idx));
end

% ========================================================================
%  Axis Formatting, Limits & Typography
% ========================================================================
box(ax, 'off');   % Strip top/right border lines
grid(ax, 'off');  % Clean white background

% Domain Bounds
xlim(ax, [1, TotalIterations]);

% Dynamic Range Bounds with Headroom
max_regret = max(baseline_trajectories_regret(:));
if isnan(max_regret) || max_regret == 0
    ylim(ax, [0, 1]);
else
    ylim(ax, [0, max_regret * 1.05]);
end

% Tick Marks
xticks(ax, [1, 600, 1200, 1800, 2400, 3000, 3600, 4200]);

% Typography
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontName', 'Arial');
ylabel(ax, 'Mean Instantaneous Regret (Problem Size 8)', 'FontSize', 16, 'FontName', 'Arial', 'Interpreter', 'tex');

set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% 2-Column Legend Box
lgd = legend(ax, p_reg, 'Location', 'NorthEast', 'NumColumns', 2, 'FontSize', 9.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');

hold(ax, 'off');