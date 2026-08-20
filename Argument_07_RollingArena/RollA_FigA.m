clear;
clc;
close all;
base_dir = 'I:\2026 Performance Improvment\Data\SensorChanging\RollingArena\Dataset';
dir_content = dir(fullfile(base_dir, 'RollingArena_New_*'));
if isempty(dir_content)
    error('No directories matching ''RollingArena_New_*'' were found in: %s', base_dir);
end
folder_names = {dir_content.name};
parsed_combos = [];

for f = 1:length(folder_names)
    tokens = regexp(folder_names{f}, 'RollingArena_New_(\d+)_(\d+)_(\d+)', 'tokens');
    if ~isempty(tokens)
        outer_val  = str2double(tokens{1}{1});
        middle_val = str2double(tokens{1}{2});
        % Calculate total iterations: (2 * outer) + (3 * middle)
        total_iter = (outer_val * 2) + (middle_val * 3);
        % Store: [Total Iterations, Outer, Middle, Index of original folder]
        parsed_combos = [parsed_combos; total_iter, outer_val, middle_val, f];
    end
end
[~, sort_idx] = sort(parsed_combos(:, 1), 'ascend');
sorted_combos = parsed_combos(sort_idx, :);
num_folders = size(sorted_combos, 1);
algorithms = { ...
    "noalgorithm", "greedy", "egreedy", "UCB", "UCBbay", ...
    "bernoulli", "Poisson", "Normal", "bothNormal", ...
    "UCBTemp025", "UCBTemp075", "UCBTuned", "FVTS", "MTS", ...
    "NewNormal", "NewFVTS", "NewUCBBayes" ...
    };
TargetNumRuns = 1000;
days = 1;


%% Calculating the drop rate, accuracy and the instantaneous regret here.
num_folders = size(sorted_combos, 1);
num_algos   = length(algorithms);
max_trials  = 4200;  
accuracy_ratio_matrix = NaN(num_algos, num_folders);
% Dimensions: [17 Algorithms x N Folders x 4200 Trials]
regret_trajectories_tensor = NaN(num_algos, num_folders, max_trials); 
x_labels = cell(1, num_folders);
% --- Main Processing Loop Over Found Folders ---
for c = 1:num_folders
    total_iter = sorted_combos(c, 1);
    outer_val  = sorted_combos(c, 2);
    middle_val = sorted_combos(c, 3);
    orig_f_idx = sorted_combos(c, 4);
    
    folder_name = folder_names{orig_f_idx};
    x_labels{c} = sprintf('%d', total_iter); 
    
    data_root = fullfile(base_dir, folder_name, 'OptimizationBaseline', 'RawRT', 'Divisor15');
    
    fprintf('\n=========================================================================\n');
    fprintf('EVALUATING FOLDER: %s | Calculated Total: %d\n', folder_name, total_iter);
    fprintf('=========================================================================\n');
    fprintf('%-14s | %-13s | %-13s | %-8s | %-8s | %-8s | %-8s\n', ...
        'Algorithm', 'Drop True %', 'Reach True %', '1st Chg', '2nd Chg', '3rd Chg', '4th Chg');
    fprintf('%s\n', repmat('-', 1, 95));

    for a_idx = 1:num_algos
        algo = algorithms{a_idx};
        struct_name = strcat("dist_", algo, num2str(15));
        div_name = strcat("divisor", num2str(15));
        
        fileName = sprintf('%d%s1000.mat', total_iter, algo);
        fullFilePath = fullfile(data_root, fileName);
        
        if exist(fullFilePath, 'file')
            sim_load = load(fullFilePath, 'dat1');
            dt = sim_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
            
            [~, ~, ~, posActualValues] = calculate_accuracy_convergence_with_rolling_arena(...
                dt, days, TargetNumRuns, algo, total_iter);
            
            % --- CAPTURE FULL TRIAL-BY-TRIAL REGRET TRAJECTORY ---
            regret_curve = calculate_trial_level_regret_Mean_Curve(dt); % Returns 1 x TotalIter array
            num_t = length(regret_curve);
            
            % Store full trajectory in the 3D tensor
            regret_trajectories_tensor(a_idx, c, 1:num_t) = regret_curve;
            
            dropped_true_global_count = 0;
            reached_global_best_count = 0;
            change_timesteps = NaN(TargetNumRuns, 4);
            
            for sim = 1:TargetNumRuns
                mHist = dt.mask_history{sim, 1};
                
                true_global_min_val = min(mHist(:, 1));
                global_best_rows = find(abs(mHist(:, 1) - true_global_min_val) < 1e-6);
                
                was_ever_dropped = false;
                for r_idx = 1:length(global_best_rows)
                    if mHist(global_best_rows(r_idx), 4) > 0
                        was_ever_dropped = true;
                    end
                end
                if was_ever_dropped
                    dropped_true_global_count = dropped_true_global_count + 1;
                end
                if abs(posActualValues(sim) - true_global_min_val) < 1e-6
                    reached_global_best_count = reached_global_best_count + 1;
                end
                
                all_transitions = [mHist(:, 3); mHist(:, 4)];
                valid_changes = unique(all_transitions(all_transitions > 0));
                valid_changes = sort(valid_changes, 'ascend');
                
                num_detected = min(length(valid_changes), 4);
                if num_detected > 0
                    change_timesteps(sim, 1:num_detected) = valid_changes(1:num_detected);
                end
            end
            
            pct_dropped_global = (dropped_true_global_count / TargetNumRuns) * 100;
            pct_reached_global = (reached_global_best_count / TargetNumRuns) * 100;
            avg_changes = nanmean(change_timesteps, 1); 
            accuracy_ratio_matrix(a_idx, c) = pct_reached_global / 100;   
            fprintf('%-14s | %-13.2f | %-13.2f | %-8.1f | %-8.1f | %-8.1f | %-8.1f\n', ...
                algo, pct_dropped_global, pct_reached_global, ...
                avg_changes(1), avg_changes(2), avg_changes(3), avg_changes(4));
        else
            fprintf('%-14s | %-75s\n', algo, 'Missing File Structure Link');
        end
    end
end
% --- SAVE EXTRACTED METRICS & FULL REGRET TENSOR TO DISK ---
output_data_file = 'extracted_rolling_arena_full_trajectories.mat';
save(output_data_file, 'accuracy_ratio_matrix', 'regret_trajectories_tensor', 'x_labels', 'algorithms', 'sorted_combos');
fprintf('\n Successfully saved full trial regret trajectories tensor to: %s\n', output_data_file);

%% Figure that shows accuracy of using different configuration for optimization in case of rolling arena
 clear;
 load('extracted_rolling_arena_full_trajectories.mat');
 num_folders = size(sorted_combos, 1);
fig_accuracy = figure('Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 950, 550]);
ax_acc = axes('Parent', fig_accuracy);
hold(ax_acc, 'on');
selected_keys = {"noalgorithm", "UCB", "UCBTemp025", "egreedy"};
legend_labels_4 = { ...
    'Brute Force (BF)', ...
    'UCB1', ...
    'UCB Temp 0.25', ...
    '\epsilon-Greedy' ...
};
markers_bank = {'o', 's', 'd', '^'};
% High-contrast color palette matching your main CPA trajectory script
custom_colors = [ ...
    0.0000, 0.4470, 0.7410; ... % Blue (BF)
    0.8500, 0.3250, 0.0980; ... % Red/Orange (UCB1)
    0.4940, 0.1840, 0.5560; ... % Purple (UCB Temp 0.25)
    0.4660, 0.6740, 0.1880        % Green (e-Greedy)
];
% --- FILTERS & PLOTS ONLY SELECTED KEY ROWS ---
plot_handles_acc = [];
valid_legends_acc = {};
for idx = 1:length(selected_keys)
    algo_key = selected_keys{idx};
    row_idx = find(strcmp(cellstr(algorithms), cellstr(algo_key))); 
    if ~isempty(row_idx) && ~all(isnan(accuracy_ratio_matrix(row_idx, :)))
        h_line = plot(ax_acc, 1:num_folders, accuracy_ratio_matrix(row_idx, :), ...
            'LineStyle', '-', ...
            'LineWidth', 2.5, ...
            'Color', custom_colors(idx, :), ...
            'Marker', markers_bank{idx}, ...
            'MarkerSize', 7, ...
            'MarkerFaceColor', custom_colors(idx, :)); 
        plot_handles_acc(end+1) = h_line; 
        valid_legends_acc{end+1} = legend_labels_4{idx};
    end
end

xlabel(ax_acc, 'Trials', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
ylabel(ax_acc, 'Accuracy for Problem Size 8', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
box(ax_acc, 'off');
grid(ax_acc, 'off'); 
ylim(ax_acc, [0, 1]); % Strict normalization boundary
set(ax_acc, 'XTick', 1:num_folders, 'XTickLabel', x_labels, ...
    'FontName', 'Arial', 'FontSize', 15, 'LineWidth', 1.5, ...
    'TickDir', 'in', 'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
xtickangle(ax_acc, 45);
if ~isempty(plot_handles_acc)
    lgd_acc = legend(ax_acc, plot_handles_acc, valid_legends_acc, 'Location', 'SouthWest');
    set(lgd_acc, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial', 'FontSize', 12);
end
hold(ax_acc, 'off');

%% Figure A for Argument 7 : Rolling Arena. Accuracy plot for the continuous optimization and then overlayed is the accuracy observed on different configurations
clear
clc
close all
clc
load('dataps8.mat')
load('extracted_rolling_arena_full_trajectories.mat')
trial_steps = 15:15:4200;
folder_trials = cellfun(@str2double, x_labels);
fig_overlay = figure('Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 950, 550]);
ax_over = axes('Parent', fig_overlay);
hold(ax_over, 'on');
row_indices  = [1, 3, 4, 10];
algo_keys    = {"noalgorithm", "egreedy", "UCB", "UCBTemp025"};
legend_names = {'Brute Force (BF)', '\epsilon-Greedy', 'UCB1', 'UCB Temp 0.25'};
markers_bank = {'o', '^', 's', 'd'}; % Matched to row order
custom_colors = [ ...
0.0000, 0.4470, 0.7410; ... % Blue (BF - Row 1)
0.4660, 0.6740, 0.1880; ... % Green (e-Greedy - Row 3)
0.8500, 0.3250, 0.0980; ... % Red/Orange (UCB1 - Row 4)
0.4940, 0.1840, 0.5560      % Purple (UCB Temp 0.25 - Row 10)
];
plot_handles = [];
valid_legends = {};
for idx = 1:length(row_indices)
row_num = row_indices(idx);
algo_key = algo_keys{idx};
plot(ax_over, trial_steps, baseline_trajectories(row_num, :)/100, ...
'LineStyle', '-', ...
'LineWidth', 2.0, ...
'Color', custom_colors(idx, :));
acc_row_idx = find(strcmp(cellstr(algorithms), cellstr(algo_key)));
if ~isempty(acc_row_idx) && ~all(isnan(accuracy_ratio_matrix(acc_row_idx, :)))
h_marker = plot(ax_over, folder_trials, accuracy_ratio_matrix(acc_row_idx, :), ...
'LineStyle', 'none', ...
'Marker', markers_bank{idx}, ...
'MarkerSize', 8, ...
'MarkerEdgeColor', 'k', ... % Clean black outline for contrast
'MarkerFaceColor', custom_colors(idx, :));
plot_handles(end+1) = h_marker; 
valid_legends{end+1} = legend_names{idx}; 
end
end
xlabel(ax_over, 'Trials', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
ylabel(ax_over, 'Accuracy for Problem Size 8', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
box(ax_over, 'off');
grid(ax_over, 'off');
ylim(ax_over, [0, 1]);
% Clean ticks placed exactly at your folder trial checkpoints
set(ax_over, 'XTick', folder_trials, 'XTickLabel', x_labels, ...
'FontName', 'Arial', 'FontSize', 15, 'LineWidth', 1.5, ...
'TickDir', 'in', 'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
xtickangle(ax_over, 45);
if ~isempty(plot_handles)
lgd = legend(ax_over, plot_handles, valid_legends, 'Location', 'SouthWest');
set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial', 'FontSize', 12);
end
hold(ax_over, 'off');

%% Figure B for Argument 7 : Rolling Arena. Regret is the observed on different configurations
clear; clc;  
mat_file = 'extracted_rolling_arena_full_trajectories.mat';
folder_to_plot_idx = []; 
selected_keys = {"noalgorithm", "UCB", "UCBTemp025", "egreedy"};
legend_labels = { ...
    'Brute Force (BF)', ...
    'UCB1', ...
    'UCB Temp 0.25', ...
    '\epsilon-Greedy' ...
};
if ~exist(mat_file, 'file')
    error('Could not find file: %s. Run the extraction script first.', mat_file);
end
fprintf('Loading extracted Rolling Arena trajectory tensor...\n');
data_load = load(mat_file);
reg_tensor  = data_load.regret_trajectories_tensor; % [Algos x Folders x 4200]
algorithms  = data_load.algorithms;
x_labels    = data_load.x_labels;
combos      = data_load.sorted_combos;
% Determine folder index if not manually specified (default to max horizon)
if isempty(folder_to_plot_idx)
    folder_to_plot_idx = size(combos, 1); 
end
target_total_iter = combos(folder_to_plot_idx, 1);
fprintf('Plotting trial regret trajectories for Horizon: %d trials (Folder %d/%d)\n', ...
    target_total_iter, folder_to_plot_idx, size(combos, 1));
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 950, 550]);
ax  = axes('Parent', fig);
hold(ax, 'on');
custom_colors = [ ...
    0.0000, 0.4470, 0.7410; ... % Blue (BF)
    0.8500, 0.3250, 0.0980; ... % Red/Orange (UCB1)
    0.4940, 0.1840, 0.5560; ... % Purple (UCB Temp 0.25)
    0.4660, 0.6740, 0.1880        % Green (e-Greedy)
];
trial_steps = 1:target_total_iter;
plot_handles  = [];
valid_legends = {};
for idx = 1:length(selected_keys)
    algo_key = selected_keys{idx};
    a_idx = find(strcmp(cellstr(algorithms), cellstr(algo_key)));
    if ~isempty(a_idx)
        % Extract 1D trajectory across 1:target_total_iter and convert to ms
        curve = squeeze(reg_tensor(a_idx, folder_to_plot_idx, 1:target_total_iter)) * 1000;
        if ~all(isnan(curve)) && ~all(curve == 0)
            h_line = plot(ax, trial_steps, curve, '-', ...
                'Color', custom_colors(idx, :), 'LineWidth', 2.5);
            plot_handles(end+1)  = h_line; 
            valid_legends{end+1} = legend_labels{idx}; 
        end
    end
end
xlabel(ax, 'Trial Number', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', 'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');
xlim(ax, [1, target_total_iter]);
box(ax, 'off');
grid(ax, 'off');
set(ax, 'FontName', 'Arial', 'FontSize', 15, 'LineWidth', 1.5, ...
    'TickDir', 'in', 'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
if ~isempty(plot_handles)
    lgd = legend(ax, plot_handles, valid_legends, 'Location', 'NorthEast');
    set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial', 'FontSize', 12);
end
hold(ax, 'off');
fprintf(' Complete! Rolling Arena regret trajectory plot rendered.\n');
