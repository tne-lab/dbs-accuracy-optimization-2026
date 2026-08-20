%% PARALLEL PARAMETER ID TRAJECTORY PLOTTER
clear; clc; close all;
tic;
data_root = 'I:\2026 Performance Improvment\Data\SensorChanging\ContinuousParameterIdentification\RawRT\probSize8\TotalIterations4200';

algorithms = { ...
    struct("name","egreedy","params",linspace(0.01,0.5,25)), ...
    struct("name", "UCB", "params", unique([linspace(0.1, 2.0, 25), linspace(0.30, 0.55, 25)])),...
    struct('name', 'UCBTuned', 'params', linspace(0.5, 2.0, 25)), ...
    struct('name', 'UCBTemp',  'params', linspace(0.05, 0.75, 25)), ...
    struct('name', 'UCBbay',   'params', [linspace(0.001, 0.1, 15), linspace(0.12, 0.5, 10)]) ...
    };

TotalIterations = 4200;
TargetNumRuns   = 1000;
divisor = 15;
days = 1;

% Define the timeline resolution steps
trial_steps = 15:15:4200;
num_steps = length(trial_steps);
results = struct();
results.trial_steps = trial_steps; 
if isempty(gcp('nocreate'))
    parpool('local');
end

for a_idx = 1:length(algorithms)
    target_algorithm = algorithms{a_idx}.name;
    param_values = algorithms{a_idx}.params;
    num_params = length(param_values);

    % Pre-allocate trajectory matrix
    trajectories = zeros(num_params, num_steps);
    regrettrajectories  = zeros(num_params, TotalIterations);
    fprintf('>>> EXTRACTION PHASE (PARALLEL): %s...\n', target_algorithm);

    struct_name = strcat("dist_", target_algorithm, num2str(divisor));
    div_name = strcat("divisor", num2str(divisor));

    % --- PARALLEL WORKER COMPUTATION ---
    parfor p_idx = 1:num_params
        p_val = param_values(p_idx);

        fileName = sprintf('param_%.2f_%s1000.mat', p_val, target_algorithm);
        fullFilePath = fullfile(data_root, fileName);

        if exist(fullFilePath, 'file')
            sim_load = load(fullFilePath, 'dat1');
            dt_sim = sim_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};

            local_row = zeros(1, num_steps);
            Param_Trial_Regret_Mean_Curve = [];
            for t_idx = 1:num_steps
                target_t = trial_steps(t_idx);

                [acc_vals_tar, ~, ~, ~] = calculate_accuracy_convergence_with_target(...
                    dt_sim, days, TargetNumRuns, target_algorithm, target_t);

                local_row(t_idx) = acc_vals_tar(1);

            end
            Param_Trial_Regret_Mean_Curve = calculate_trial_level_regret_Mean_Curve(dt_sim);

            trajectories(p_idx, :) = local_row;
            regrettrajectories(p_idx, :) = Param_Trial_Regret_Mean_Curve;
        end
    end

    % Check if any actual simulation runs were computed/loaded
    if all(trajectories(:) == 0)
        fprintf('WARNING: No data collected for %s. Skipping figure and stats.\n', target_algorithm);
        continue;
    end

    % Creates dynamic sub-fields like results.egreedy.trajectories
    results.(target_algorithm).trajectories = trajectories;
    results.(target_algorithm).regrettrajectories = regrettrajectories;
    results.(target_algorithm).param_values = param_values;

    fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150 + (a_idx*20), 150 - (a_idx*10), 780, 520]);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    color_map = turbo(num_params);
    plot_handles = [];

    for p_idx = 1:num_params
        if any(trajectories(p_idx, :))
            p = plot(ax, trial_steps, trajectories(p_idx, :), '-', ...
                'Color', color_map(p_idx, :), 'LineWidth', 1.5);

            set(p, 'DisplayName', sprintf('\\theta = %.2f', param_values(p_idx)));
            plot_handles = [plot_handles, p];
        end
    end

    box(ax, 'off');
    grid(ax, 'off');

    xlim(ax, [150, 4200]);
    ylim(ax, [0, 1]);

    yticks(ax, 0:0.2:1);
    xticks(ax, [150, 600, 1200, 1800, 2400, 3000, 3600, 4200]);

    xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
    ylabel(ax, 'Accuracy for Problem Size 8', 'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

    set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
        'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

    title(ax, sprintf('%s Parameter Evolution Trajectories', target_algorithm), 'FontSize', 14, 'FontName', 'Arial');

    lgd = legend(ax, plot_handles, 'Location', 'EastOutside', 'FontSize', 8.5, 'FontName', 'Arial');
    set(lgd, 'Box', 'on', 'EdgeColor', [0.8 0.8 0.8], 'Color', 'w');

    hold(ax, 'off');

    % ========================================================================
    %  STATISTICAL ANALYSIS ENGINE (Inside Loop Scope)
    % ========================================================================
    fprintf('\n========================================================================\n');
    fprintf('        STATISTICAL PROFILE FOR ALGORITHM: %s\n', target_algorithm);
    fprintf('========================================================================\n');

    early_idx = 10;   % Trial 150
    final_idx = 280;  % Trial 4200

    final_accuracies = trajectories(:, final_idx);
    [max_acc, best_p_idx] = max(final_accuracies);
    best_theta = param_values(best_p_idx);

    fprintf('Identified Optimal Parameter: \\theta = %.4f (Final Acc: %.4f)\n\n', best_theta, max_acc);
    fprintf('%-12s | %-12s | %-12s | %-10s | %-15s\n', ...
        'Parameter', 'Early Acc', 'Final Acc', 'p-Value', 'Statistical Tier');
    fprintf('------------------------------------------------------------------------\n');

    for p_idx = 1:num_params
        current_theta = param_values(p_idx);
        early_acc = trajectories(p_idx, early_idx);
        final_acc = trajectories(p_idx, final_idx);

        if p_idx == best_p_idx
            p_val = 1.0000;
            tier = 'CHAMPION (★)';
        else
            champion_distribution = trajectories(best_p_idx, (final_idx-25):final_idx);
            current_distribution  = trajectories(p_idx, (final_idx-25):final_idx);

            [p_val, ~] = ranksum(champion_distribution, current_distribution, 'tail', 'right');

            if p_val < 0.05
                tier = 'Inferior (▼)';
            else
                tier = 'Stat. Equivalent (=)';
            end
        end

        fprintf('\\theta = %-7.3f | %-12.4f | %-12.4f | %-10.4f | %-15s\n', ...
            current_theta, early_acc, final_acc, p_val, tier);
    end
    fprintf('========================================================================\n\n');

end
fprintf('Saving all algorithm data into a single master file...\n');
save('all_algorithms_parameter_tuning_results_regret.mat', 'results');
toc
%% Figure for Argument 3 Hyper parameter tuning Accuracy plot with shaded area
clear; clc; close all;
master_file = 'all_algorithms_parameter_tuning_results_regret.mat';
if ~exist(master_file, 'file')
    error('File "%s" not found. Run the extraction script first.', master_file);
end
load(master_file, 'results');
target_algo = 'UCB'; % Select target algorithm key (e.g., 'UCB', 'egreedy', 'UCBTuned')
if ~isfield(results, target_algo)
    error('Algorithm "%s" not found in loaded results.', target_algo);
end
bins = [0.00 0.25; 0.30 0.45; 0.85 1.15; 1.50 2.00];
bin_labels = {
    'UCB1 c < 0.25 (Under-exploration)', ...
    'UCB1 c \in [0.30, 0.45] (Optimal)', ...
    'UCB1 c \in [0.85, 1.15] (Baseline)', ...
    'UCB1 c \in [1.50, 2.00] (Over-exploration)'
    };
colors = [0.85 0.45 0.10; 0.18 0.54 0.34; 0.12 0.47 0.71; 0.84 0.24 0.12];
trajs       = results.UCB.trajectories;
param_vals  = results.UCB.param_values;
trial_steps = 15:15:(size(trajs, 2) * 15);
fig = figure('Color', 'w', 'Position', [150, 150, 680, 680]);
ax  = axes('Parent', fig);
hold(ax, 'on');
handles = zeros(1, 4);
for b = 1:4
    idx = (param_vals >= bins(b,1) & param_vals <= bins(b,2));
    if any(idx)
        fill(ax, [trial_steps, fliplr(trial_steps)], ...
            [max(trajs(idx,:),[],1), fliplr(min(trajs(idx,:),[],1))], ...
            colors(b,:), 'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        handles(b) = plot(ax, trial_steps, mean(trajs(idx,:), 1), '-', 'Color', colors(b,:), 'LineWidth', 2.0);
    end
end
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', 'FontSize', 18, 'FontName', 'Arial');
xlim(ax, [trial_steps(1), trial_steps(end)]);
ylim(ax, [0, 1]);
xticks(ax, 600:600:4200);
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15], 'Box', 'off');
lgd = legend(ax, handles(handles ~= 0), bin_labels(handles ~= 0), 'Location', 'SouthEast', 'FontSize', 14);
set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');

%%  Figure for Argument 3 Hyper parameter tuning regret plot with shaded area
clear; clc; close all;
master_file = 'all_algorithms_parameter_tuning_results_regret.mat';
if ~exist(master_file, 'file')
    error('File "%s" not found. Run the extraction script first.', master_file);
end
load(master_file, 'results');
target_algo = 'UCB'; % Select target algorithm key (e.g., 'UCB', 'egreedy', 'UCBTuned')
if ~isfield(results, target_algo)
    error('Algorithm "%s" not found in loaded results.', target_algo);
end
reg_trajs   = results.(target_algo).regrettrajectories * 1000; % Scale to ms
param_vals  = results.(target_algo).param_values;              % Parameter array
total_trials = size(reg_trajs, 2);                            % 4200
trial_steps  = 1:total_trials;                                % 1:1:4200 continuous trials
bins = [0.00 0.25;
    0.30 0.45;
    0.85 1.15;
    1.50 2.00];
bin_labels = { ...
    'UCB c < 0.25 (Under-exploration)', ...
    'UCB c \in [0.30, 0.45] (Optimal)', ...
    'UCB c \in [0.85, 1.15] (Baseline)', ...
    'UCB c \in [1.50, 2.00] (Over-exploration)' ...
    };
colors = [0.85 0.45 0.10;
    0.18 0.54 0.34;
    0.12 0.47 0.71;
    0.84 0.24 0.12];
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 850, 580]);
ax  = axes('Parent', fig);
hold(ax, 'on');

num_bins = size(bins, 1);
handles  = zeros(1, num_bins);

for b = 1:num_bins
    % Find parameter rows falling within current bin range
    idx = (param_vals >= bins(b,1) & param_vals <= bins(b,2));

    if any(idx)
        bin_data = reg_trajs(idx, :);

        % Calculate Min, Max, and Mean across parameter rows in this bin
        upper_bound = max(bin_data, [], 1);
        lower_bound = min(bin_data, [], 1);
        mean_curve  = mean(bin_data, 1);

        % Shaded Min-Max Confidence Band
        fill(ax, [trial_steps, fliplr(trial_steps)], ...
            [upper_bound, fliplr(lower_bound)], ...
            colors(b, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');

        % Mean Regret Trajectory Line
        handles(b) = plot(ax, trial_steps, mean_curve, '-', ...
            'Color', colors(b, :), 'LineWidth', 2.0);
    end
end
box(ax, 'off');
grid(ax, 'off');

% Lock X-Axis Limits to the complete 4200 trial timeline
xlim(ax, [0, 4200]);

% Exact custom X-axis ticks using multiples of 600
set(ax, 'XTick', 0:600:4200);

% Title
title(ax, sprintf('%s Binned Parameter Regret Trajectories', target_algo), ...
    'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'bold');

% Axis Labels
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% --- LEGEND ARCHITECTURE ---
valid_handles = handles(handles ~= 0);
if ~isempty(valid_handles)
    lgd = legend(ax, valid_handles, bin_labels(handles ~= 0), ...
        'Location', 'NorthEast', ...
        'FontSize', 13);
    set(lgd, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial');
end

hold(ax, 'off');

%%  Figure for Argument 3 Hyper parameter tuning regret plot across all the parameter values
clear; clc;
master_file = 'all_algorithms_parameter_tuning_results_regret.mat';
if ~exist(master_file, 'file')
    error('File "%s" not found. Run the extraction script first.', master_file);
end
load(master_file, 'results');
target_algo = 'UCB'; % Select target algorithm key (e.g., 'UCB', 'egreedy', 'UCBTuned')
if ~isfield(results, target_algo)
    error('Algorithm "%s" not found in loaded results.', target_algo);
end
reg_trajs   = results.(target_algo).regrettrajectories * 1000; % Scale to ms
param_vals  = results.(target_algo).param_values;              % Parameter array
num_params  = length(param_vals);
total_trials = size(reg_trajs, 2);                            % 4200
trial_steps  = 1:total_trials;                                % 1:1:4200 continuous trials
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [150, 150, 850, 580]);
ax  = axes('Parent', fig);
hold(ax, 'on');
color_map = turbo(num_params);
plot_handles = zeros(1, num_params);
for p_idx = 1:num_params
    p_val = param_vals(p_idx);
    curve = reg_trajs(p_idx, :);

    plot_handles(p_idx) = plot(ax, trial_steps, curve, '-', ...
        'Color', color_map(p_idx, :), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('c = %.2f', p_val));
end
box(ax, 'off');
grid(ax, 'off');
xlim(ax, [0, 4200]);
set(ax, 'XTick', 0:600:4200);
title(ax, sprintf('%s Continuous Parameter Regret Trajectories', target_algo), ...
    'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'bold');
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');
set(ax, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
lgd = legend(ax, plot_handles, 'Location', 'EastOutside', 'FontSize', 8.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', [0.8 0.8 0.8], 'Color', 'w');
hold(ax, 'off');