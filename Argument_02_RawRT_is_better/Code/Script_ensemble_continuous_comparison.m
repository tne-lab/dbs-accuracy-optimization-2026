algorithms =  ["noalgorithm","greedy","egreedy","UCB","UCBbay", ...
    "bernoulli","Poisson","Normal","bothNormal", ...
    "UCBTemp025","UCBTemp075","UCBTuned","FVTS","MTS", ...
    "NewNormal","NewFVTS","NewUCBBayes"];
%% ============================================================
% Figure 6A: Selection Accuracy Plot (Cumulative Trial X-Ticks)
% Single Axis | No-Box/No-Grid | Inward Ticks | Opaque Legend
% Balanced Visual Weight & Lower-Right Solid Backdrop Legend
fileEnsemble   = 'Results_NewRawRT.mat';
fileContinuous = 'Results_Continuous_Accuracy_prob8_RawRT.mat';
% Load datasets safely
if ~exist(fileEnsemble, 'file') || ~exist(fileContinuous, 'file')
    error('Make sure both data files exist in your current MATLAB path.');
end
dataEns = load(fileEnsemble);    resEns = dataEns.results_accumulator;
dataCon = load(fileContinuous);  resCon = dataCon.results_accumulator;
dayList = 1:7;
iterationList = 600:600:4200;
numDays = length(dayList);
ens_ucb = nan(1, numDays); ens_bf = nan(1, numDays);
con_ucb = nan(1, numDays); con_bf = nan(1, numDays);
pld = 'Day'; if ~isfield(resEns.UCB, pld), pld = 'Iterations'; end
for d = 1:numDays
    dayField = sprintf('Day%d', dayList(d));
    if isfield(resEns.UCB.(pld), dayField)
        ens_ucb(d) = resEns.UCB.(pld).(dayField).Mean_Selection_accuracy(1);
    end
    if isfield(resEns.noalgorithm.(pld), dayField)
        ens_bf(d)  = resEns.noalgorithm.(pld).(dayField).Mean_Selection_accuracy(1);
    end
end
for d = 1:numDays
    iterField = sprintf('Iter%d', iterationList(d));
    if isfield(resCon.UCB.Iterations, iterField)
        con_ucb(d) = resCon.UCB.Iterations.(iterField).Mean_Selection_accuracy(1);
    end
    if isfield(resCon.noalgorithm.Iterations, iterField)
        con_bf(d)  = resCon.noalgorithm.Iterations.(iterField).Mean_Selection_accuracy(1);
    end
end
% ============================================================
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue (BF)
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red (UCB1)
% Muted 3-Element RGB Mixes for background Ensemble vectors
colorBF_muted  = [0.4000, 0.5624, 0.6870]; 
colorUCB_muted = [0.8800, 0.4847, 0.4682];
% Controlled publication-grade window framework dimensions
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 650, 520]);
ax = axes('Parent', fig);
hold(ax, 'on');
% Layer 1: Background Reference (Ensemble — Dashed, Open Circles)
p1 = plot(ax, dayList, ens_bf, '--o', ...
    'Color', colorBF_muted, 'LineWidth', 1.4, ...
    'MarkerSize', 6.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorBF_muted, ...
    'DisplayName', 'BF - Ensemble'); 
p2 = plot(ax, dayList, ens_ucb, '--o', ...
    'Color', colorUCB_muted, 'LineWidth', 1.4, ...
    'MarkerSize', 6.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorUCB_muted, ...
    'DisplayName', 'UCB1 - Ensemble');

% Layer 2: Foreground Metrics (Continuous Focus — Solid, Filled Squares)
p3 = plot(ax, dayList, con_bf, '-s', ...
    'Color', colorBF, 'LineWidth', 2.0, ... 
    'MarkerSize', 7.0, 'MarkerFaceColor', colorBF, ...
    'DisplayName', 'BF - Continuous');
p4 = plot(ax, dayList, con_ucb, '-s', ...
    'Color', colorUCB, 'LineWidth', 2.0, ... 
    'MarkerSize', 7.0, 'MarkerFaceColor', colorUCB, ...
    'DisplayName', 'UCB1 - Continuous');
box(ax, 'off'); 
grid(ax, 'off');  
xlim(ax, [min(dayList), max(dayList)]);
ylim(ax, [0, 1]);
yticks(ax, 0:0.2:1);
xticks(ax, dayList);
set(ax, 'XTickLabel', {'600', '1200', '1800', '2400', '3000', '3600', '4200'});
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
lgd = legend(ax, [p3, p4, p1, p2], 'Location', 'SouthEast', 'NumColumns', 1, 'FontSize', 11.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');
hold(ax, 'off');


%%
%% ============================================================
% Figure 6A: Selection Accuracy Plot with Baseline Overlay
% Single Axis | No-Box/No-Grid | Inward Ticks | Opaque Legend
%% ============================================================

% Define the filenames for datasets
fileEnsemble   = 'Results_NewRawRT.mat';
fileContinuous = 'Results_Continuous_Accuracy_prob8_RawRT.mat';

% Load datasets safely
if ~exist(fileEnsemble, 'file') || ~exist(fileContinuous, 'file')
    error('Make sure both data files exist in your current MATLAB path.');
end
dataEns = load(fileEnsemble);    resEns = dataEns.results_accumulator;
dataCon = load(fileContinuous);  resCon = dataCon.results_accumulator;

dayList = 1:7;
iterationList = 600:600:4200;
numDays = length(dayList);

% Map days (1:7) to actual trial numbers (600:600:4200) for alignment
x_trials_discrete = 600 * dayList; 

% Preallocate performance vectors
ens_ucb = nan(1, numDays); ens_bf = nan(1, numDays);
con_ucb = nan(1, numDays); con_bf = nan(1, numDays);

% --- Data Extraction ---
% A. Ensemble Method Data Extraction
pld = 'Day'; if ~isfield(resEns.UCB, pld), pld = 'Iterations'; end
for d = 1:numDays
    dayField = sprintf('Day%d', dayList(d));
    if isfield(resEns.UCB.(pld), dayField)
        ens_ucb(d) = resEns.UCB.(pld).(dayField).Mean_Selection_accuracy(1);
    end
    if isfield(resEns.noalgorithm.(pld), dayField)
        ens_bf(d)  = resEns.noalgorithm.(pld).(dayField).Mean_Selection_accuracy(1);
    end
end

% B. Continuous Method Data Extraction
for d = 1:numDays
    iterField = sprintf('Iter%d', iterationList(d));
    if isfield(resCon.UCB.Iterations, iterField)
        con_ucb(d) = resCon.UCB.Iterations.(iterField).Mean_Selection_accuracy(1);
    end
    if isfield(resCon.noalgorithm.Iterations, iterField)
        con_bf(d)  = resCon.noalgorithm.Iterations.(iterField).Mean_Selection_accuracy(1);
    end
end

% ============================================================
% Figure Generation & Styling
% ============================================================
% High-Contrast Bold Base Palette
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue (BF)
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red (UCB1)
colorBF_muted  = [0.4000, 0.5624, 0.6870]; 
colorUCB_muted = [0.8800, 0.4847, 0.4682];
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 650, 520]);
ax = axes('Parent', fig);
hold(ax, 'on');
if exist('baseline_trajectories', 'var')
    if ~exist('trial_steps', 'var')
        trial_steps = 15:15:4200;
    end
    p_bl_bf  = plot(ax, trial_steps, baseline_trajectories(1, :)/100, ':', ...
        'Color', colorBF_muted, 'LineWidth', 1.6, 'DisplayName', 'BF - Baseline');
    p_bl_ucb = plot(ax, trial_steps, baseline_trajectories(4, :)/100, ':', ...
        'Color', colorUCB_muted, 'LineWidth', 1.6, 'DisplayName', 'UCB1 - Baseline');
end
p1 = plot(ax, x_trials_discrete, ens_bf, '--o', ...
    'Color', colorBF_muted, 'LineWidth', 1.4, ...
    'MarkerSize', 6.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorBF_muted, ...
    'DisplayName', 'BF - Ensemble'); 
p2 = plot(ax, x_trials_discrete, ens_ucb, '--o', ...
    'Color', colorUCB_muted, 'LineWidth', 1.4, ...
    'MarkerSize', 6.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorUCB_muted, ...
    'DisplayName', 'UCB1 - Ensemble');
p3 = plot(ax, x_trials_discrete, con_bf, '-s', ...
    'Color', colorBF, 'LineWidth', 2.0, ... 
    'MarkerSize', 7.0, 'MarkerFaceColor', colorBF, ...
    'DisplayName', 'BF - Continuous');
p4 = plot(ax, x_trials_discrete, con_ucb, '-s', ...
    'Color', colorUCB, 'LineWidth', 2.0, ... 
    'MarkerSize', 7.0, 'MarkerFaceColor', colorUCB, ...
    'DisplayName', 'UCB1 - Continuous');
box(ax, 'off');   % Strip top and right border lines
grid(ax, 'off');  % Strip background grid lines
xlim(ax, [150, 4200]);
ylim(ax, [0, 1]);
yticks(ax, 0:0.2:1);
xticks(ax, [150, 600, 1200, 1800, 2400, 3000, 3600, 4200]);
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);
if exist('baseline_trajectories', 'var')
    lgd = legend(ax, [p3, p4, p1, p2, p_bl_bf, p_bl_ucb], 'Location', 'SouthEast', ...
        'NumColumns', 1, 'FontSize', 10.0, 'FontName', 'Arial');
else
    lgd = legend(ax, [p3, p4, p1, p2], 'Location', 'SouthEast', ...
        'NumColumns', 1, 'FontSize', 11.5, 'FontName', 'Arial');
end
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');
hold(ax, 'off');

%%
%% ============================================================
% Figure 6A: Selection Accuracy Plot (Ensemble vs Continuous Baseline)
% Single Axis | No-Box/No-Grid | Inward Ticks | Opaque Legend
%% ============================================================

% Define the filename for Ensemble dataset only
fileEnsemble = 'Results_NewRawRT.mat';
 load('continuous_dataset_regret.mat')
if ~exist(fileEnsemble, 'file')
    error('Make sure Results_NewRawRT.mat exists in your current MATLAB path.');
end
if ~exist('baseline_trajectories', 'var')
    error('baseline_trajectories variable not found in workspace.');
end

dayList = 1:7;
iterationList = 600:600:4200;
numDays = length(dayList);

% Map days (1:7) to actual trial numbers (600:600:4200)
x_trials_discrete = 600 * dayList; 

% Set up baseline steps vector if not in workspace
if ~exist('trial_steps', 'var')
    trial_steps = 15:15:4200;
end

%% --- Data Extraction ---
% A. Ensemble Method Data Extraction
dataEns = load(fileEnsemble);
resEns  = dataEns.results_accumulator;

ens_ucb = nan(1, numDays); 
ens_bf  = nan(1, numDays);

pld = 'Day'; if ~isfield(resEns.UCB, pld), pld = 'Iterations'; end
for d = 1:numDays
    dayField = sprintf('Day%d', dayList(d));
    if isfield(resEns.UCB.(pld), dayField)
        ens_ucb(d) = resEns.UCB.(pld).(dayField).Mean_Selection_accuracy(1);
    end
    if isfield(resEns.noalgorithm.(pld), dayField)
        ens_bf(d)  = resEns.noalgorithm.(pld).(dayField).Mean_Selection_accuracy(1);
    end
end

% B. Continuous Data Extraction (Extracted directly from baseline_trajectories at 600:600:4200)
% Note: Row 1 = noalgorithm (BF), Row 4 = UCB
[~, target_indices] = ismember(iterationList, trial_steps);

con_bf  = baseline_trajectories(1, target_indices) / 100;
con_ucb = baseline_trajectories(4, target_indices) / 100;

%% ============================================================
% Figure Generation & Styling
%% ============================================================
% High-Contrast Bold Base Palette
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue (BF)
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red (UCB1)

% Muted 3-Element RGB Mixes for Ensemble background vectors
colorBF_muted  = [0.4000, 0.5624, 0.6870]; 
colorUCB_muted = [0.8800, 0.4847, 0.4682];

% Controlled publication-grade window framework dimensions
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 650, 520]);
ax = axes('Parent', fig);
hold(ax, 'on');

%% Layer 1: Ensemble Method (Dashed Lines, Open Circles)
p1 = plot(ax, x_trials_discrete, ens_bf, '--o', ...
    'Color', colorBF_muted, 'LineWidth', 1.4, ...
    'MarkerSize', 6.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorBF_muted, ...
    'DisplayName', 'BF - Ensemble'); 
p2 = plot(ax, x_trials_discrete, ens_ucb, '--o', ...
    'Color', colorUCB_muted, 'LineWidth', 1.4, ...
    'MarkerSize', 6.0, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorUCB_muted, ...
    'DisplayName', 'UCB1 - Ensemble');

%% Layer 2: Continuous Baseline Method (Solid Lines, Filled Squares at 600:600:4200)
p3 = plot(ax, x_trials_discrete, con_bf, '-s', ...
    'Color', colorBF, 'LineWidth', 2.0, ... 
    'MarkerSize', 7.0, 'MarkerFaceColor', colorBF, ...
    'DisplayName', 'BF - Continuous');
p4 = plot(ax, x_trials_discrete, con_ucb, '-s', ...
    'Color', colorUCB, 'LineWidth', 2.0, ... 
    'MarkerSize', 7.0, 'MarkerFaceColor', colorUCB, ...
    'DisplayName', 'UCB1 - Continuous');

%% ============================================================
% Axis Formatting, Limits & Typography
%% ============================================================
box(ax, 'off');   % Strip top and right border lines
grid(ax, 'off');  % Strip background grid lines

% Axis Limits
xlim(ax, [600, 4200]);
ylim(ax, [0, 1]);

% Clean steps for the framework coordinates
yticks(ax, 0:0.2:1);
xticks(ax, [600, 1200, 1800, 2400, 3000, 3600, 4200]);

% Labels matching target geometry
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Accuracy for Problem Size 8', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

%% Clean Single-Column Legend with Solid White Backdrop Block
lgd = legend(ax, [p3, p4, p1, p2], 'Location', 'SouthEast', ...
    'NumColumns', 1, 'FontSize', 11.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');

hold(ax, 'off');