clear; clc; close all;
tic;
data_root = 'I:\2026 Performance Improvment\Data\SensorChanging\CPAOptimization\probSize8\RawRT\Divisor15';
algorithms = { ...
    "noalgorithm", "greedy", "egreedy", "UCB", "UCBbay", ...
    "bernoulli", "Poisson", "Normal", "bothNormal", ...
    "UCBTemp025", "UCBTemp075", "UCBTuned", "FVTS", "MTS", ...
    "NewNormal", "NewFVTS", "NewUCBBayes" ...
    };
TargetNumRuns = 1000;
divisor = 15;
days = 1;
trial_steps = 15:15:4200;
num_steps = length(trial_steps);

%% Code for creating the dataset from the data for CPA optimization
cpa_results = struct();
cpa_results.trial_steps = trial_steps;
if isempty(gcp('nocreate'))
    parpool('local');
end
fprintf('STARTING CPA TIMELINE EXTRACTION (15 TO 4200 TRIALS)...\n\n');
for a_idx = 1:length(algorithms)
    target_algorithm = algorithms{a_idx};
    struct_name = strcat("dist_", target_algorithm, num2str(divisor));
    div_name = strcat("divisor", num2str(divisor));
    fileName = sprintf('CPA_4200_analysis_%s1000.mat', target_algorithm);
    fullFilePath = fullfile(data_root, fileName);
    if exist(fullFilePath, 'file')
        fprintf(' [FOUND] Extracting full timeline for: %s\n', target_algorithm);
        sim_load = load(fullFilePath, 'dat1');
        dt_sim = sim_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
        local_row = zeros(1, num_steps);
        parfor t_idx = 1:num_steps
            target_t = trial_steps(t_idx);
            [acc_vals_tar, ~, ~, ~] = calculate_accuracy_convergence_with_cpa_shuffle(...
                dt_sim, days, TargetNumRuns, target_algorithm, target_t);
            local_row(t_idx) = acc_vals_tar(1);
        end
        cpa_results.(target_algorithm).trajectories = local_row;
    else
        fprintf(' [MISSING] File not found for: %s. Skipping.\n', target_algorithm);
        cpa_results.(target_algorithm).trajectories = NaN(1, num_steps);
    end
end
output_file = 'trajectrory_extracted_cpa_timeline_results.mat';
save(output_file, 'cpa_results');
fprintf('\n Done! Complete CPA trajectories saved cleanly to: %s\n', output_file);

toc
%% Figure A for Argument 6: CPA showing the robustness
clear; clc;
trial_steps = 15:15:4200;
load('trajectrory_extracted_cpa_timeline_results.mat');
fprintf('Generating beautified comparison plot...\n');
selected_keys = {'noalgorithm', 'UCB', 'UCBTemp025', 'egreedy'};
legend_labels_4 = { ...
    'Brute Force (BF)', ...
    'UCB1', ...
    'UCB Temp 0.25', ...
    '\epsilon-Greedy' ...
    };

% --- OPTIONAL: ALL ALGORITHMS REFERENCE TEMPLATE (COMMENTED OUT) ---
% If you want to switch back to plotting everything, uncomment this block
% and update custom_colors to match your desired number of lines.
% ------------------------------------------------------------------------
% selected_keys = { ...
%     'noalgorithm', 'greedy', 'egreedy', 'UCB', 'UCBbay', ...
%     'bernoulli', 'Poisson', 'Normal', 'bothNormal', ...
%     'UCBTemp025', 'UCBTemp075', 'UCBTuned', 'FVTS', 'MTS', ...
%     'NewNormal', 'NewFVTS', 'NewUCBBayes' ...
% };
%
% legend_labels_4 = { ...
%     'Brute Force (BF)', 'Greedy', '\epsilon-Greedy', 'UCB1', 'Bayesian UCB', ...
%     'Bernoulli TS', 'Poisson TS', 'Normal', 'Both Normal', ...
%     'UCB Temp 0.25', 'UCB Temp 0.75', 'UCB Tuned', 'FVTS', 'MTS', ...
%     'New Normal', 'New FVTS', 'New UCB Bayes' ...
% };
% ------------------------------------------------------------------------

% High-contrast color palette dynamically adapting if you change selection sizes
if length(selected_keys) == 4
    custom_colors = [ ...
        0.0000, 0.4470, 0.7410; ... % Blue
        0.8500, 0.3250, 0.0980; ... % Red/Orange
        0.4940, 0.1840, 0.5560; ... % Purple
        0.4660, 0.6740, 0.1880        % Green
        ];
else
    custom_colors = lines(length(selected_keys)); % Autumn fallback for larger arrays
end
fig_4 = figure('Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 950, 550]);
ax_4 = axes('Parent', fig_4);
hold(ax_4, 'on');
xline(ax_4, 2100, '--', 'CPA Environmental Shift', ...
    'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, 'LabelOrientation', 'aligned', 'FontSize', 12);

% --- PLOT ENGINE ---
plot_handles_4 = [];
valid_legends = {};

for idx = 1:length(selected_keys)
    algo_key = selected_keys{idx};

    if isfield(cpa_results, algo_key) && ~any(isnan(cpa_results.(algo_key).trajectories))
        h_line = plot(ax_4, trial_steps, cpa_results.(algo_key).trajectories, ...
            '-', 'Color', custom_colors(idx, :), 'LineWidth', 2.5);

        plot_handles_4(end+1) = h_line;
        valid_legends{end+1} = legend_labels_4{idx};
    end
end

% --- STYLING & AXIS ARCHITECTURE ---
xlabel(ax_4, 'Trial Number', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
ylabel(ax_4, 'Accuracy for Problem Size 8', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
% Title left out entirely as requested

% Bounds & Ticks
xlim(ax_4, [15 4200]);
ylim(ax_4, [0 1]); % Locked strictly to 0-1
xticks(ax_4, [15, 600, 1200, 1800, 2100, 2700, 3300, 3900, 4200]);
yticks(ax_4, 0:0.2:1);

% Clean presentation styling (Grid removed)
box(ax_4, 'off');
grid(ax_4, 'off');
set(ax_4, 'FontName', 'Arial', 'FontSize', 15, 'LineWidth', 1.5, ...
    'TickDir', 'in', 'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% Elegant Legend placement (Box removed)
if ~isempty(plot_handles_4)
    % Dynamically handle layout if you swap in all 17 algorithms
    if length(valid_legends) > 4
        num_cols = 3;
        loc = 'SouthEast';
    else
        num_cols = 1;
        loc = 'SouthWest';
    end

    lgd4 = legend(ax_4, plot_handles_4, valid_legends, 'Location', loc, 'NumColumns', num_cols);
    set(lgd4, 'Box', 'off', 'Color', 'none', 'FontName', 'Arial', 'FontSize', 12);
end

hold(ax_4, 'off');
fprintf('Complete! Your clean, publication-ready plot is rendered.\n');