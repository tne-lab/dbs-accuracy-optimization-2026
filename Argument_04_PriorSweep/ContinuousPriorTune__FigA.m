%%  PARALLEL PRIOR SENSITIVITY SWEEP (MULTI-ALGORITHM DATA EXTRACTION)
clear; clc; close all;
tic;
data_root = 'I:\2026 Performance Improvment\Data\SensorChanging\PriorSensitivitySweepContinuous\RawRT\Divisor15\probSize8\TotalIterations4200';
% Core configurations (Includes UCB1 r)
algorithms = ["NewUCBBayes", "NewNormal", "NewFVTS", "Normal", "bothNormal", "FVTS", "MTS"];
prior_scenarios = ["Baseline", "Pessimistic_Mu", "Optimistic_Mu", ...
                   "Overconfident_Lambda", "Underconfident_Lambda", ...
                   "Variance_Bias_High", "Variance_Bias_Low"];
TotalIterations = 4200;
TargetNumRuns   = 1000;
divisor = 15;
days = 1;
trial_steps = 15:15:4200;
num_steps = length(trial_steps);
if isempty(gcp('nocreate'))
    parpool('local'); 
end
% Format will be: all_extracted_data.(algorithm_name) = [scenarios x steps]
all_extracted_data = struct();
all_extracted_data_regret = struct();

% ========================================================================
%  MASTER EXTRACTION LOOP
% ========================================================================
for a_idx = 1:length(algorithms)
    target_algorithm = algorithms(a_idx);
    num_scenarios = length(prior_scenarios);
    
    % Allocation matches total scenario count exactly for this loop
    trajectories = zeros(num_scenarios, num_steps);
    
    fprintf('>>> Extractions Running For: %s...\n', target_algorithm);
    
    % Create structural name and sanitize spaces for struct field mapping
    struct_name = strcat("dist_", target_algorithm, num2str(divisor));
    struct_name = strrep(struct_name, ' ', '_'); 
    div_name = strcat("divisor", num2str(divisor));
    
    % --- PARALLEL EXTRACTION FOR ALL SCENARIOS ---
    parfor s_idx = 1:num_scenarios
        current_scenario = prior_scenarios(s_idx);
        fileName = sprintf('%s%s%d.mat', current_scenario, target_algorithm, TargetNumRuns);
        
        % Dynamic path checks handle baseline subfolders seamlessly
        potentialPaths = {
            fullfile(data_root, current_scenario, fileName), ...
            fullfile(data_root, 'Baseline', fileName), ...
            fullfile(data_root, 'Baseline', current_scenario, fileName), ...
            fullfile(data_root, fileName)
        };
        
        fullFilePath = '';
        for p = 1:length(potentialPaths)
            if exist(potentialPaths{p}, 'file')
                fullFilePath = potentialPaths{p};
                break;
            end
        end
        
        if ~isempty(fullFilePath)
            sim_load = load(fullFilePath, 'dat1');
            dt_sim = sim_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
            
            local_row = zeros(1, num_steps);
            for t_idx = 1:num_steps
                [acc_vals_tar, ~, ~, ~] = calculate_accuracy_convergence_with_target(...
                    dt_sim, days, TargetNumRuns, target_algorithm, trial_steps(t_idx));
                local_row(t_idx) = acc_vals_tar(1); 
            end
            Param_Trial_Regret_Mean_Curve = calculate_trial_level_regret_Mean_Curve(dt_sim);
            trajectories(s_idx, :) = local_row;
            regrettrajectories(s_idx, :) = Param_Trial_Regret_Mean_Curve;
        end
    end
    
    % Save data to the master structure if validation checks pass
    if all(trajectories(:) == 0)
        fprintf('WARNING: No data found for %s in any checked directory.\n', target_algorithm);
    else
        % Sanitize field names within the master structure (e.g., UCB1_r instead of UCB1 r)
        safe_algo_field = strrep(target_algorithm, ' ', '_');
        all_extracted_data.(safe_algo_field) = trajectories;
        all_extracted_data_regret.(safe_algo_field) = regrettrajectories;
    end
end
output_filename = 'AllAlgorithms_PriorSensitivity_Trajectories_regret.mat';
save(output_filename, 'all_extracted_data', 'all_extracted_data_regret', 'prior_scenarios', 'algorithms', 'trial_steps', '-v7.3');
fprintf('\n>>> EXTRACTION COMPLETE: Data saved cleanly to %s <<<\n', output_filename);
toc

%% Figure for Argument 04: Prior Senstivity analysis
clear; clc; close all;
mat_file = 'AllAlgorithms_PriorSensitivity_Trajectories_regret.mat';
active_algo = 'NewUCBBayes'; 
display_name = 'Block-Variance Bayes-UCB';
if ~exist(mat_file, 'file')
    error('Could not find the prior sensitivity file: %s. Run extraction first.', mat_file);
end
fprintf('Loading extracted sensitivity records...\n');
load(mat_file, 'all_extracted_data', 'prior_scenarios', 'trial_steps');
safe_algo_field = strrep(active_algo, ' ', '_');
if ~isfield(all_extracted_data, safe_algo_field)
    error('Field "%s" is missing from the extracted MAT file structure.', safe_algo_field);
end
all_trajectories = all_extracted_data.(safe_algo_field);
param_map = { ...
    'Baseline',             'Baseline'; ...
    'Pessimistic_Mu',       'Pessimistic Mean'; ...
    'Optimistic_Mu',        'Optimistic Mean'; ...
    'Overconfident_Lambda', 'Overconfident Precision'; ...
    'Variance_Bias_High',   'High Variance Bias'; ...
    'Variance_Bias_Low',    'Low Variance Bias' ...
};
valid_indices = [];
lgd_labels = {};

for p_idx = 1:size(param_map, 1)
    raw_name = param_map{p_idx, 1};
    data_idx = find(prior_scenarios == raw_name, 1);
    
    if ~isempty(data_idx)
        valid_indices(end+1) = data_idx; 
        lgd_labels{end+1} = param_map{p_idx, 2}; 
    end
end
trajectories = all_trajectories(valid_indices, :);
num_scenarios = length(valid_indices);
fprintf('Rendering comprehensive trajectory variations for %s...\n', display_name);
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 850, 580]);
ax = axes('Parent', fig);
hold(ax, 'on');
plot_handles = zeros(1, num_scenarios);
for s_idx = 1:num_scenarios
    raw_scenario_name = prior_scenarios(valid_indices(s_idx));
    if strcmp(raw_scenario_name, 'Baseline')
        line_width = 3.0;
        line_style = '--';  % Dashed baseline for clear distinction
        plot_handles(s_idx) = plot(ax, trial_steps, trajectories(s_idx, :), line_style, ...
            'LineWidth', line_width);
    else
        line_width = 2.0;
        line_style = '-';
        plot_handles(s_idx) = plot(ax, trial_steps, trajectories(s_idx, :), line_style, ...
            'LineWidth', line_width);
    end
end
title(ax, display_name, 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'bold');
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
lgd = legend(ax, plot_handles, lgd_labels, ...
    'Location', 'SouthEast', ...
    'NumColumns', 3, ...
    'FontSize', 13);
set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');

hold(ax, 'off');
fprintf('Complete! Legend items updated to show pure text scenario labels.\n');

%% Figure for Argument 04 Prior sensitivity analysis : Regret plot
clear; clc; close all;
mat_file = 'AllAlgorithms_PriorSensitivity_Trajectories_regret.mat';
%  CONTROL PANEL: Target algorithm within the dataset
active_algo  = 'NewUCBBayes'; 
display_name = 'Block-Variance Bayes-UCB';
% --- LOAD DATA ---
if ~exist(mat_file, 'file')
    error('Could not find the prior sensitivity file: %s. Run extraction first.', mat_file);
end
fprintf('Loading extracted sensitivity records...\n');
load(mat_file, 'all_extracted_data_regret', 'prior_scenarios', 'trial_steps');
safe_algo_field = strrep(active_algo, ' ', '_');
if ~isfield(all_extracted_data_regret, safe_algo_field)
    error('Field "%s" is missing from "all_extracted_data_regret". Check available field names.', safe_algo_field);
end
all_trajectories = all_extracted_data_regret.(safe_algo_field) * 1000;
param_map = { ...
    'Baseline',             'Baseline'; ...
    'Pessimistic_Mu',        'Pessimistic Mean'; ...
    'Optimistic_Mu',         'Optimistic Mean'; ...
    'Overconfident_Lambda', 'Overconfident Precision'; ...
    'Variance_Bias_High',   'High Variance Bias'; ...
    'Variance_Bias_Low',    'Low Variance Bias' ...
};
valid_indices = [];
lgd_labels = {};

for p_idx = 1:size(param_map, 1)
    raw_name = param_map{p_idx, 1};
    data_idx = find(prior_scenarios == raw_name, 1);
    
    if ~isempty(data_idx)
        valid_indices(end+1) = data_idx; 
        lgd_labels{end+1} = param_map{p_idx, 2}; 
    end
end

trajectories = all_trajectories(valid_indices, :);
num_scenarios = length(valid_indices);

% --- RESOLVE TIMELINE X-AXIS ---
num_cols = size(trajectories, 2);
if num_cols == 4200
    plot_x = 1:4200;
elseif num_cols == length(trial_steps)
    plot_x = trial_steps;
else
    plot_x = linspace(1, 4200, num_cols);
end
% --- VISUALIZATION SETUP ---
fprintf('Rendering prior sensitivity regret trajectories for %s...\n', display_name);
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 850, 580]);
ax  = axes('Parent', fig);
hold(ax, 'on');
plot_handles = zeros(1, num_scenarios);
% --- PLOT ALL VARIATIONS ---
for s_idx = 1:num_scenarios
    raw_scenario_name = prior_scenarios(valid_indices(s_idx));
    
    if strcmp(raw_scenario_name, 'Baseline')
        line_width = 3.0;
        line_style = '--';  % Dashed baseline anchor
        plot_handles(s_idx) = plot(ax, plot_x, trajectories(s_idx, :), line_style, ...
            'LineWidth', line_width);
    else
        line_width = 2.0;
        line_style = '-';
        plot_handles(s_idx) = plot(ax, plot_x, trajectories(s_idx, :), line_style, ...
            'LineWidth', line_width);
    end
end
box(ax, 'off');
grid(ax, 'off');
xlim(ax, [0, 4200]);
set(ax, 'XTick', 0:600:4200);
title(ax, sprintf('%s Prior Sensitivity Regret Trajectories', display_name), ...
    'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'bold');
% Axis Labels (Matched word-for-word and size-for-size)
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% --- LEGEND ARCHITECTURE ---
lgd = legend(ax, plot_handles, lgd_labels, ...
    'Location', 'NorthEast', ...
    'NumColumns', 2, ...
    'FontSize', 12);
set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');

hold(ax, 'off');
fprintf('Complete! Plot layout matched to reference specifications.\n');