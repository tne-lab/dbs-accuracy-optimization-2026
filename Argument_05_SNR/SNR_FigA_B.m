%%  SNR SWEEP TIMELINE EXTRACTION SCRIPT (FULL TRAJECTORIES FOR SNR_1 TO SNR_6)
% ========================================================================
clear; clc; close all;
tic;

snr_base_root = 'I:\2026 Performance Improvment\Data\SensorChanging\SNRSweep\probSize8';

algorithms = { ...
    "noalgorithm", "greedy", "egreedy", "UCB", "UCBbay", ...
    "bernoulli", "Poisson", "Normal", "bothNormal", ...
    "UCBTemp025", "UCBTemp075", "UCBTuned", "FVTS", "MTS", ...
    "NewNormal", "NewFVTS", "NewUCBBayes" ...
};

snr_list = 1:6;
TargetNumRuns = 1000;
divisor = 15;
days = 1;

% Define the full timeline steps up to 4200
trial_steps = 15:15:4200;
num_steps = length(trial_steps);

snr_timeline_results = struct();
snr_timeline_results.trial_steps = trial_steps;
snr_timeline_results.snr_levels = snr_list;

snr_timeline_results_regret = struct();
snr_timeline_results_regret.trial_steps = trial_steps;
snr_timeline_results_regret.snr_levels = snr_list;

if isempty(gcp('nocreate'))
    parpool('local'); 
end

fprintf('🚀 STARTING SNR TIMELINE EXTRACTION (15 TO 4200 TRIALS FOR ALL SNRs)...\n\n');

for a_idx = 1:length(algorithms)
    target_algorithm = algorithms{a_idx};
    fprintf('Processing: %s\n', target_algorithm);
    
    struct_name = strcat("dist_", target_algorithm, num2str(divisor));
    div_name = strcat("divisor", num2str(divisor));
    
    % Allocation matrix: [6 SNR Levels x 280 Steps]
    algorithm_matrix = zeros(length(snr_list), num_steps);
    regrettrajectories  = zeros(length(snr_list), 4200);

    for s_idx = 1:length(snr_list)
        current_snr = snr_list(s_idx);
        snr_folder_path = fullfile(snr_base_root, sprintf('SNR_%d', current_snr), 'RawRT', 'Divisor15');
        
        % Target the 4200 analysis file within each SNR folder
        fileName = sprintf('snr_%d_analysis_%s1000.mat', current_snr, target_algorithm);
        fullFilePath = fullfile(snr_folder_path, fileName);
        
        if exist(fullFilePath, 'file')  
            sim_load = load(fullFilePath, 'dat1');
            dt_sim = sim_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
            
            local_row = zeros(1, num_steps);
            parfor t_idx = 1:num_steps
                target_t = trial_steps(t_idx);
                [acc_vals_tar, ~, ~, ~] = calculate_accuracy_convergence_with_target(...
                    dt_sim, days, TargetNumRuns, target_algorithm, target_t);
                local_row(t_idx) = acc_vals_tar(1);
            end
            algorithm_matrix(s_idx, :) = local_row;
            Param_Trial_Regret_Mean_Curve = calculate_trial_level_regret_Mean_Curve(dt_sim);
            regrettrajectories(s_idx, :) = Param_Trial_Regret_Mean_Curve;
        else
            algorithm_matrix(s_idx, :) = NaN(1, num_steps);
        end
    end
    snr_timeline_results.(target_algorithm).snr_trajectories = algorithm_matrix;
    snr_timeline_results_regret.(target_algorithm).snr_trajectories_regret = regrettrajectories;
end

output_file = 'extracted_snr_timeline_curves.mat';
save(output_file, 'snr_timeline_results', 'snr_timeline_results_regret');
fprintf('\n Done! All SNR timelines saved cleanly to: %s\n', output_file);
toc
%% Figure A for Argument 05 all the SNR  BF vs UCB1
clear; clc; close all;
% --- CONFIGURATION ---
mat_file = 'extracted_snr_timeline_curves.mat';
% --- LOAD DATA ---
if ~exist(mat_file, 'file')
    error('Could not find the extracted SNR timeline file: %s.', mat_file);
end
fprintf(' Loading extracted SNR timeline records...\n');
load(mat_file, 'snr_timeline_results');
trial_steps = snr_timeline_results.trial_steps;
bf_matrix  = snr_timeline_results.noalgorithm.snr_trajectories;
ucb_matrix = snr_timeline_results.UCB.snr_trajectories;
fprintf('Rendering comprehensive 6-SNR tracking matrix...\n');
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 1000, 650]);
ax = axes('Parent', fig);
hold(ax, 'on');
default_colors = get(ax, 'ColorOrder');
plot_handles = zeros(1, 12);
labels       = cell(1, 12);
for s_idx = 1:6
    current_color = default_colors(mod(s_idx-1, size(default_colors,1))+1, :);
    % Index math to stack them cleanly in the legend arrays
    bf_pos  = (s_idx - 1) * 2 + 1;
    ucb_pos = (s_idx - 1) * 2 + 2;
    % 1. Plot Brute Force (BF) -> Solid Line
    plot_handles(bf_pos) = plot(ax, trial_steps, bf_matrix(s_idx, :), '-', ...
        'Color', current_color, 'LineWidth', 2.0);
    labels{bf_pos} = sprintf('BF: SNR_{%d}', s_idx);
    
    % 2. Plot UCB1 -> Dashed Line
    plot_handles(ucb_pos) = plot(ax, trial_steps, ucb_matrix(s_idx, :), '--', ...
        'Color', current_color, 'LineWidth', 2.0);
    labels{ucb_pos} = sprintf('UCB1: SNR_{%d}', s_idx);
end
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', 'FontSize', 18, 'FontName', 'Arial');
xlim(ax, [150, 4200]); 
ylim(ax, [0, 1]);
xticks(ax, [150, 600, 1200, 1800, 2400, 3000, 3600, 4200]); 
yticks(ax, 0:0.2:1);
box(ax, 'off');   
grid(ax, 'off');  
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
lgd = legend(ax, plot_handles, labels, ...
    'Location', 'SouthEast', ...
    'NumColumns', 2, ...
    'FontSize', 11);
set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');
hold(ax, 'off');
fprintf('Complete! Full 6-SNR gradient matrix generated successfully.\n');
%% Figure A for Argument 05 for the high SNR  and low SNR BF vs UCB1
clear; clc; close all;
mat_file = 'extracted_snr_timeline_curves.mat';
if ~exist(mat_file, 'file')
    error('Could not find the extracted SNR timeline file: %s.', mat_file);
end
fprintf('Loading extracted SNR timeline records...\n');
load(mat_file, 'snr_timeline_results');
trial_steps = snr_timeline_results.trial_steps;
bf_matrix  = snr_timeline_results.noalgorithm.snr_trajectories;
ucb_matrix = snr_timeline_results.UCB.snr_trajectories;
fprintf('Rendering tracking curves with symbolic methods-aligned labels...\n');
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 850, 580]);
ax = axes('Parent', fig);
hold(ax, 'on');
default_colors = get(ax, 'ColorOrder');
c_high_snr = default_colors(1, :); % Blue (1st Default)
c_low_snr  = default_colors(2, :); % Orange (2nd Default)
% --- PLOT LINE INTERLEAVING ---
% 1. High SNR (SNR 1): Brute Force (BF) -> Solid Blue
h(1) = plot(ax, trial_steps, bf_matrix(1, :), '-', 'Color', c_high_snr, 'LineWidth', 2.5);
% 2. High SNR (SNR 1): UCB1 -> Dashed Blue
h(2) = plot(ax, trial_steps, ucb_matrix(1, :), '--', 'Color', c_high_snr, 'LineWidth', 2.5);

% 3. Low SNR (SNR 6): Brute Force (BF) -> Solid Orange
h(3) = plot(ax, trial_steps, bf_matrix(6, :), '-', 'Color', c_low_snr, 'LineWidth', 2.5);
% 4. Low SNR (SNR 6): UCB1 -> Dashed Orange
h(4) = plot(ax, trial_steps, ucb_matrix(6, :), '--', 'Color', c_low_snr, 'LineWidth', 2.5);
labels = { ...
    'BF: SNR_{High}', ...
    'UCB1: SNR_{High}', ...
    'BF: SNR_{Low}', ...
    'UCB1: SNR_{Low}' ...
};
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', 'FontSize', 18, 'FontName', 'Arial');
xlim(ax, [150, 4200]); 
ylim(ax, [0, 1]);
xticks(ax, [150, 600, 1200, 1800, 2400, 3000, 3600, 4200]); 
yticks(ax, 0:0.2:1);
box(ax, 'off');   
grid(ax, 'off');  
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
lgd = legend(ax, h, labels, 'Location', 'SouthEast', 'FontSize', 12);
set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');
hold(ax, 'off');
fprintf('Complete! Ready for final manuscript export.\n');

%% Figure B for Argument 05 for all SNR  BF vs UCB1
clear; clc; close all;

% --- CONFIGURATION ---
mat_file     = 'extracted_snr_timeline_curves.mat';
plot_algo    = 'NewUCBBayes'; 
display_name = 'Block-Variance Bayes-UCB';

% --- LOAD EXTRACTED DATA ---
if ~exist(mat_file, 'file')
    error('Could not find file: %s. Run the extraction script first.', mat_file);
end

data_load = load(mat_file);

% Target the updated saved structure name
if isfield(data_load, 'snr_timeline_results_regret')
    snr_data = data_load.snr_timeline_results_regret;
else
    error('Unable to locate "snr_timeline_results" inside %s.', mat_file);
end

% Verify target algorithm existence
if ~isfield(snr_data, plot_algo)
    error('Algorithm "%s" is missing from dataset.', plot_algo);
end

% Extract trajectory matrix (6 SNRs x 4200 Trials) and scale to ms
algo_struct = snr_data.(plot_algo);

if isstruct(algo_struct) && isfield(algo_struct, 'snr_trajectories_regret')
    reg_trajs = algo_struct.snr_trajectories_regret * 1000;
else
    error('Field "snr_trajectories_regret" not found under algorithm "%s".', plot_algo);
end

% Set up timeline axes
snr_list        = 1:size(reg_trajs, 1);
full_trial_axis = 1:size(reg_trajs, 2);

fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 850, 580]);
ax  = axes('Parent', fig);
hold(ax, 'on');

num_snrs     = length(snr_list);
color_map    = lines(num_snrs); 
plot_handles = zeros(1, num_snrs);
lgd_labels   = cell(1, num_snrs);

for s_idx = 1:num_snrs
    curve = reg_trajs(s_idx, :);
    
    % Skip missing/unprocessed SNR files
    if all(isnan(curve)) || all(curve == 0)
        continue;
    end
    
    plot_handles(s_idx) = plot(ax, full_trial_axis, curve, '-', ...
        'Color', color_map(s_idx, :), 'LineWidth', 2.0);
    lgd_labels{s_idx}   = sprintf('SNR %d', snr_list(s_idx));
end

% Filter out empty line handles
valid_mask    = (plot_handles ~= 0);
valid_handles = plot_handles(valid_mask);
valid_labels  = lgd_labels(valid_mask);

box(ax, 'off');
grid(ax, 'off');

% Lock X-Axis Limits to the complete 4200 trial timeline
xlim(ax, [0, 4200]);

% Exact custom X-axis ticks using multiples of 600
set(ax, 'XTick', 0:600:4200);

% Title
title(ax, sprintf('%s SNR Sweep Regret Trajectories', display_name), ...
    'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'bold');

% Axis Labels
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% Legend Architecture
if ~isempty(valid_handles)
    lgd = legend(ax, valid_handles, valid_labels, ...
        'Location', 'NorthEast', ...
        'NumColumns', 2, ...
        'FontSize', 12);
    set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');
end

hold(ax, 'off');