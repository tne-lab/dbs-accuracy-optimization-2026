%% ============================================================
% Combined Trial-Level Regret Plot (Day 7)
% Single Axis | BF & UCB Comparison | X-Baseline vs Raw RT
%% ============================================================

% File setup for both conditions
fileXBase = 'Results_NewXBaseline.mat';
fileRawRT = 'Results_NewRawRT.mat';

if ~exist(fileXBase, 'file') || ~exist(fileRawRT, 'file')
    error('Make sure both "Results_NewXBaseline.mat" and "Results_NewRawRT.mat" exist in your MATLAB path.');
end

dataXBase = load(fileXBase); resXBase = dataXBase.results_accumulator;
dataRawRT = load(fileRawRT); resRawRT = dataRawRT.results_accumulator;

targetDay = 'Day7';

%% --- Palette & Styling Configuration ---
% Primary Colors (Raw RT - Foreground)
colorBF  = [0.0000, 0.2706, 0.4784]; % Deep Navy Blue (BF)
colorUCB = [0.8000, 0.1412, 0.1137]; % Crimson Red (UCB)

% Muted Colors (X-Baseline - Background Reference)
colorBF_muted  = [0.4000, 0.5624, 0.6870]; 
colorUCB_muted = [0.8800, 0.4847, 0.4682];

%% --- Curve Extraction & Unit Conversion ---
getCurveMS = @(resStruct, algo) resStruct.(algo).Day.(targetDay).Trial_Param_Regret_Mean_Curve(:) * 1000;

bf_xbase  = getCurveMS(resXBase, 'noalgorithm');
ucb_xbase = getCurveMS(resXBase, 'UCB');
bf_rawrt  = getCurveMS(resRawRT, 'noalgorithm');
ucb_rawrt = getCurveMS(resRawRT, 'UCB');

nTrials = length(bf_rawrt);

%% ============================================================
% Figure Generation
%% ============================================================
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [200, 150, 650, 520]);
ax = axes('Parent', fig);
hold(ax, 'on');

%% Layer 1: Background Reference (X-Baseline — Dashed Lines)
p1 = stairs(ax, bf_xbase, '--', 'LineWidth', 1.4, 'Color', colorBF_muted, ...
    'DisplayName', 'BF - X_{base}');
p2 = stairs(ax, ucb_xbase, '--', 'LineWidth', 1.4, 'Color', colorUCB_muted, ...
    'DisplayName', 'UCB1 - X_{base}');

%% Layer 2: Foreground Metrics (Raw RT — Solid Lines)
p3 = stairs(ax, bf_rawrt, '-', 'LineWidth', 2.0, 'Color', colorBF, ...
    'DisplayName', 'BF - RT');
p4 = stairs(ax, ucb_rawrt, '-', 'LineWidth', 2.0, 'Color', colorUCB, ...
    'DisplayName', 'UCB1 - RT');

%% ============================================================
% Axis Formatting, Limits & Typography
%% ============================================================
box(ax, 'off');   % Strip top and right border lines
grid(ax, 'off');  % Strip background grid lines

% Lock X-Axis Limits
xlim(ax, [0, nTrials]);

% Exact custom X-axis ticks using multiples of 600
set(ax, 'XTick', 0:600:nTrials);

% Dynamic Y limits based on data peaks
all_curves = [bf_xbase; ucb_xbase; bf_rawrt; ucb_rawrt];
minY = min(all_curves) - 3; 
maxY = max(all_curves);
ylim(ax, [floor(minY), ceil(maxY + (maxY - minY)*0.05)]);

% Labels and Fonts with TeX Interpreter
xlabel(ax, 'Trial number', 'FontSize', 15, 'FontWeight', 'normal', 'FontName', 'Arial');
ylabel(ax, 'Mean Trial Regret for Problem Size 8 in ms', ...
    'FontSize', 17, 'FontName', 'Arial', 'Interpreter', 'tex');

% Professional Axis Linework
set(ax, 'FontName', 'Arial', 'FontSize', 13.5, 'LineWidth', 1.4, 'TickDir', 'in', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15]);

%% Clean Legend with Solid White Backdrop Block
lgd = legend(ax, [p3, p4, p1, p2], 'Location', 'SouthEast', 'NumColumns', 1, ...
    'FontSize', 11.5, 'FontName', 'Arial');
set(lgd, 'Box', 'on', 'EdgeColor', 'none', 'Color', 'w');

hold(ax, 'off');