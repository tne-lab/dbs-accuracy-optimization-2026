%% ========================================================================
%  CROSS-DATASET MILESTONE EVALUATOR (PURE DATA-DRIVEN TRACKING)
%  ========================================================================
clear; clc; close all;
tic;

% --- FILE PATH CONFIGURATION ---
baseline_root    = 'I:\2026 Performance Improvment\Data\SensorChanging\ContinuedOverDaysOptimization\OptimizationBaseline\RawRT\Divisor15\probSize8';
convergence_base = 'I:\2026 Performance Improvment\Data\SensorChanging\Convergence';

% All 7 version folder names to iterate over
version_folders = ["ConvIter4200_Version1", "ConvIter4200_Version2", "ConvIter4200_Version3", ...
                   "ConvIter4200_Version4", "ConvIter4200_Version5", "ConvIter4200_Version6", ...
                   "ConvIter4200_Version7"];

algorithms = ["noalgorithm","greedy","egreedy","UCB","UCBbay","bernoulli","Poisson",...
"Normal","bothNormal","UCBTemp025","UCBTemp075","UCBTuned",...
"FVTS","MTS","NewNormal","NewFVTS","NewUCBBayes"];

TotalIterations = 4200;
TargetNumRuns   = 1000;
divisor = 15;
days = 1;
target_arm_idx = 1;

fprintf('>>> EXTRACTING PURE DATA-DRIVEN ACCURACY STRATIFICATIONS...\n');

% --- OUTER LOOP: CONVERGENCE DATASETS VERSION 1 TO 7 ---
for v_idx = 1:length(version_folders)
    current_version = version_folders(v_idx);
    convergence_root = fullfile(convergence_base, current_version, 'probSize8\RawRT\Divisor15');
    
    fprintf('\n=======================================================================================================\n');
    fprintf('PROCESSING RUN COLLECTION: %s\n', current_version);
    fprintf('=======================================================================================================\n');

    % Initialize specific reporting metrics as column vectors or cell arrays for THIS version
    Report_Algos = cell(length(algorithms), 1);
    Report_Avg_Halt_Trial = zeros(length(algorithms), 1);
    Report_Conv_Acc_At_Halt = zeros(length(algorithms), 1);
    Report_Baseline_Acc_At_Halt = zeros(length(algorithms), 1);
    Report_Baseline_Acc_At_4200 = zeros(length(algorithms), 1);

    parfor a_idx = 1:length(algorithms)
        algoStr = char(algorithms(a_idx));
        algoKey = regexprep(algoStr, '[^a-zA-Z0-9]', '_');
        fileName = sprintf('%d%s1000.mat', TotalIterations, algoStr);
        baseline_file = fullfile(baseline_root, fileName);
        conv_file     = fullfile(convergence_root, fileName);
        
        % Ensure both target files exist for this specific version run before calling functions
        if ~exist(baseline_file, 'file') || ~exist(conv_file, 'file')
            continue;
        end
        
        % --- Load Baseline ---
        bl_load = load(baseline_file, 'dat1');
        struct_name = strcat("dist_", algoStr, num2str(divisor));
        div_name = strcat("divisor", num2str(divisor));
        dt_baseline    = bl_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
        [acc_vals_bl, CombinedData_bl, ~, ~] = calculate_accuracy(dt_baseline, days, TargetNumRuns, algorithms(a_idx));
        
        % --- Load Convergence ---
        co_load = load(conv_file, 'dat1');
        dt_co_load    = co_load.dat1.(struct_name).data.test1.(div_name).model8.expV.episodeV{1,1};
        [acc_vals_co, CombinedData_co, ~, ~] = calculate_accuracy_convergence_with_target_convergencev(dt_co_load, days, TargetNumRuns, algorithms(a_idx));
        Param_Trial_Regret_Mean_Curve = calculate_trial_level_regret_Mean_Curve(dt_co_load);
        % Calculate the number of trials here
        aver_value = mean(cellfun('size', CombinedData_co, 1));
        
        % --- Load Baseline up to Convergence Halt Target ---
        [acc_vals_bl_tar, CombinedData_bl_tar, ~, ~] = calculate_accuracy_convergence_with_target(dt_baseline, days, TargetNumRuns, algorithms(a_idx), round(aver_value));
        
        % =====================================================================
        % POPULATE REPORTING ARRAYS (Grabbing the final/end accuracy percentage)
        % =====================================================================
        Report_Algos{a_idx}               = algoStr;
        Report_Avg_Halt_Trial(a_idx)       = aver_value;
        Report_Conv_Acc_At_Halt(a_idx)     = acc_vals_co(1) * 100;     % Conv accuracy at halting point
        Report_Baseline_Acc_At_Halt(a_idx) = acc_vals_bl_tar(1) * 100; % Baseline accuracy at halting point
        Report_Conv_regret_At_Halt{a_idx}     = Param_Trial_Regret_Mean_Curve;
        Report_Baseline_Acc_At_4200(a_idx) = acc_vals_bl(1) * 100;     % Baseline accuracy at full 4200 run
    end

    % Construct explicit comparative chart for current dataset folder
    Milestone_Table = table(Report_Algos, Report_Avg_Halt_Trial, Report_Conv_Acc_At_Halt, ...
        Report_Baseline_Acc_At_Halt, Report_Baseline_Acc_At_4200, ...
        'VariableNames', {'Algorithm', 'Avg_Halt_Trial', 'Conv_Acc_At_Halt_Pct', ...
        'Baseline_Acc_At_Halt_Pct', 'Baseline_Acc_At_4200_Pct'});

    fprintf('TRUE TRIAL CHECKPOINT REFLECTIONS: PURE DATA-DRIVEN PROFILE ');
    fprintf('=======================================================================================================\n');
    disp(Milestone_Table);
    data_overall{v_idx,1} = Milestone_Table;
    data_overall{v_idx,2} = Report_Conv_regret_At_Halt;
    
end
toc

%% Figure for Argument 02 for convergence criteria & Baseline plot
clc
clear
close all
load('Convergence_Continuous_accuracy.mat'); % in case we don't want to
% rerun
% load('dataps8.mat');
trial_steps = 15:15:4200;
num_runs = size(data_overall, 1);
sample_table = data_overall{1};
algo_names_overall = string(sample_table.Algorithm);

% Flatten scatter data points cleanly into single long vertical vectors
all_trials = [];
all_conv_acc = [];
algo_labels_flat = [];

for r = 1:num_runs
    t_run = data_overall{r};
    
    % Force into consistent column vectors to prevent dimension mismatches
    all_trials = [all_trials; t_run.Avg_Halt_Trial(:)];
    all_conv_acc = [all_conv_acc; (t_run.Conv_Acc_At_Halt_Pct(:) / 100)];
    algo_labels_flat = [algo_labels_flat; algo_names_overall(:)];
end

% ========================================================================
%  Figure Generation & Styling (Matching Publication Architecture)
%  ========================================================================
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue (BF)
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red (UCB1)

% Controlled publication-grade window framework dimensions
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 700, 540]);
ax = axes('Parent', fig);
hold(ax, 'on');

% Dynamic scale checker for the trajectories matrix (ensures 0-1 decimal scaling)
if max(baseline_trajectories(:)) > 1.0
    scale_factor = 100;
else
    scale_factor = 1;
end

% Dynamically locate rows within the baseline_trajectories matrix
idx_bf_line  = find(algorithms == "noalgorithm");
idx_ucb_line = find(algorithms == "UCB");

algo_baseline_bf  = baseline_trajectories(idx_bf_line, :) / scale_factor;
algo_baseline_ucb = baseline_trajectories(4, :) / scale_factor;

% --- Layer 1: Continuous Baseline Smooth Trajectories ---
p1 = plot(ax, trial_steps, algo_baseline_bf, '-', ... 
    'Color', colorBF, 'LineWidth', 2.2, 'DisplayName', 'BF - Baseline Trajectory');
p2 = plot(ax, trial_steps, algo_baseline_ucb, '-', ... 
    'Color', colorUCB, 'LineWidth', 2.2, 'DisplayName', 'UCB1 - Baseline Trajectory');

% --- Layer 2: Dynamic Convergence Stopping Checkpoints (Points Only) ---
idx_bf_scat = (algo_labels_flat == "noalgorithm");
p3 = scatter(ax, all_trials(idx_bf_scat), all_conv_acc(idx_bf_scat), 80, ...
    'MarkerFaceColor', colorBF, 'MarkerEdgeColor', 'w', ...
    'MarkerFaceAlpha', 0.85, 'LineWidth', 0.8, 'DisplayName', 'BF - Convergence Halts');

idx_ucb_scat = (algo_labels_flat == "UCB");
p4 = scatter(ax, all_trials(idx_ucb_scat), all_conv_acc(idx_ucb_scat), 80, ...
    'MarkerFaceColor', colorUCB, 'MarkerEdgeColor', 'w', ...
    'MarkerFaceAlpha', 0.85, 'LineWidth', 0.8, 'DisplayName', 'UCB1 - Convergence Halts');

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

% Labels matching your target thesis geometry exactly
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', 'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework Framework Elements
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

% Clean Legend with Solid White Backdrop Block
lgd = legend(ax, [p1, p2, p3, p4], 'Location', 'SouthEast', 'NumColumns', 1, ...
             'FontSize', 11, 'FontName', 'Arial', 'Interpreter', 'none');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');

hold(ax, 'off');