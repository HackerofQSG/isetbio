%% s_DAMain.m
%
% Source:  
%  Dynamical Adaptation in Photoreceptors (2013)
%  Clark et al.
%  https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1003289#abstract0
%
% Illustrates the parameter and use of the DA_integrate routine, also
% provided in the paper as Supplementary Information, Figure 2
%
% Downloaded and edited by Wandell
%
% See also
%   DA_integrate.m
%
% Original work is licensed under a Creative Commons Attribution-ShareAlike
% 3.0 Unported License. CC-BY-SA
% Damon A. Clark, 2013
%
% This script modified for clarity from the original (Wandell)
%

%% First, this is the form of the parameter set

p.A = 1; % alpha in model
p.B = 0.2; % beta in the model
p.C = 0.5; % gamma in the model
p.tau_r = 30; % these are the timescales
p.tau_y = 50;
p.n_y = 2;
p.tau_z = 60;
p.n_z = 3;

%% Next, generate the stimulus to be used

ints = 2.^(2:8);
S = reshape([zeros(length(ints),200),ints'*ones(1,1000),zeros(length(ints),500)]',1,[]);

%% Now, call the integration routine

R = DA_integrate(S,p);

%% Compare with tau_r set to 0
p.tau_r=0;
R0 = DA_integrate(S,p);

%% Plot them up

ieNewGraphWin([],'tall');

subplot(2,1,1);
plot(S,'k');
ylabel('stimulus amplitude');
subplot(2,1,2); hold on;
plot(R,'k');
plot(R0,'r');
legend('tau_r = 30','tau_r = 0');
ylabel('response amplitude');
xlabel('time (a.u.)');

%%



