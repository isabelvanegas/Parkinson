% SurroundSuppression - no task for subject - just fixation, while a sequence of screens come up with different center
% and surround contrasts, with "center" refering to regions of the screen that flicker

% ***************************************************** BASIC SET - UP 
clear all;
load parPP
SITE = 'C';     % T = TCD, C = City College, E = EGI in City College
commandwindow;
if SITE=='C'|SITE=='E'
    TheUsualParamsCRT_Dell_lores      % this script defines some useful parameters of the monitor, trigger port, etc common to all experiments
    par.BGcolor=midgray;
elseif SITE == 'T'
    TheUsualParamsCRT_TCD
    par.BGcolor=midgray;
end

%Define TemporalFreq, SpatialFreq for BG and CNT, SpatialPhaseShift and Orientations
par.numconds = 2;   % 4 3 number of stimulus conditions (does not include contrasts)
par.spatfreqBG = 1 *ones(par.numconds,1); %1 cpd to 7 cpd
par.spatfreqCNT = 1 *ones(par.numconds,1);
par.spatphaseBG = [pi 0]; %[pi 0]; 0 = Spatial IN-phase, pi = spatial OUT-OF-Phase
par.spatphaseCNT = [0] *ones(par.numconds,1);
par.oriBG = [0 0];  %[0 0] BG's stripes orientation 0 = vertical, pi/2 = horizontal
par.oriCNT = 0 *ones(par.numconds,1); %  Disc's stripes orientation 0 = vertical, pi/2 = horizontal
par.videoFrate = 100; %60 for 7.5 100 for 25Hz
par.FlickF = 25; %25Hz or less..7.2
par.contrastsBG = [0 50 100]/100; %
par.contrastsCNT =  [0 25 50 75 100]/100;
par.trialsPerCond = [4 4];
par.numtrials = length(par.contrastsCNT)*length(par.contrastsBG)*sum(par.trialsPerCond); %*8
par.trialdur = 2.4;
par.discrad_deg = 2;    % disc radius
par.posx = [4.7 -4.7 -3.5 3.5]; par.posy = [- 1.7 -1.7 3.5 3.5]; %Use this for four discs
%par.posx = [0]; par.posy = [0]; %Use this for one disc in the center
par.useEL = 1;  % use the eye tracker?
par.leadintime = 1000;

dlg_title = 'Surround Suppression';
while 1
    prompt = {'Enter SUBJECT/RUN/TASK IDENTIFIER:','EEG? (1=yes, 0=no)'};
    def = {par.runID,num2str(par.recordEEG)};
    answer = inputdlg(prompt,dlg_title,1,def);
    par.runID = answer{1};
    par.recordEEG = str2num(answer{2});
    if exist([par.runID '.mat'],'file'), 
        dlg_title = [par.runID '.mat EXISTS ALREADY - CHOOSE ANOTHER, OR DELETE THAT ONE IF IT IS RUBBISH'];
    else
        break;
    end
end

% SOUND STUFF
Fs = 22050; % Hz
High = 0.3*sin(2*pi*500*[0:1/Fs:0.1]);
si = hanning(Fs/100)';
env = [si(1:round(length(si)/2)) ones(1,length(High)-2*round(length(si)/2)) fliplr(si(1:round(length(si)/2)))];
hHigh = audioplayer(High.*env, Fs);

Low = 0.4*sin(2*pi*200*[0:1/Fs:0.3]);
si = hanning(Fs/100)';
env = [si(1:round(length(si)/2)) ones(1,length(Low)-2*round(length(si)/2)) fliplr(si(1:round(length(si)/2)))];
hLow = audioplayer(Low.*env, Fs);

% Set up for triggers
if par.recordEEG
    if SITE=='C'
        % USB port (posing as Serial Port) for triggers
        [port, errmsg] = IOPort('OpenSerialPort', 'COM3','BaudRate=115200');
        IOPort('Write', port, uint8([setpulsedur 2 0 0 0]))   % pulse width given by last 4 numbers (each a byte, little-endian)
    elseif SITE=='E'
        port = hex2dec('1130'); %%% WARNING WARNING! MIGHT HAVE TO CHECK IN DEVICE MANAGER!
        lptwrite(port,0);
    elseif SITE=='T'
        % Parallel Port for triggers - set to zero to start
        port = 888;
        lptwrite(port,0);
    end
end

% for contrasts:
load gammafnDell_lores100
alph = [0:0.0001:1];
alpha2contrast=(((255-midgray)*alph+midgray).^gam - (midgray-midgray*alph).^gam)./(((255-midgray)*alph+midgray).^gam+(midgray-midgray*alph).^gam+2*b0./Cg);

if par.useEL, ELCalibrateDialog, end

% Opens a graphics window on the main monitor
window = Screen('OpenWindow', whichScreen, par.BGcolor);

if abs(hz-par.videoFrate)>1
    error(['The monitor is NOT SET to the desired frame rate of ' num2str(par.videoFrate) ' Hz. Change it.'])
end

if par.useEL
    %%%%%%%%% EYETRACKING PARAMETERS
    par.FixWinSize = 3;    % RADIUS of fixation (circular) window in degrees
    par.TgWinSize = 3;    % RADIUS of fixation (circular) window in degrees
    ELsetupCalib
    Eyelink('Command', 'clear_screen 0')
    Eyelink('command', 'draw_box %d %d %d %d 15', center(1)-deg2px*par.FixWinSize, center(2)-deg2px*par.FixWinSize, center(1)+deg2px*par.FixWinSize, center(2)+deg2px*par.FixWinSize);
end

%  *************************** TIMING
% all in ms - in the task trial loop /1000 to sec
par.fixperiod = 500;    % how long to wait after fixation to start stimulating
par.ITI = 500;

%  **********************  MAKE STIMULI
%%%%%%%%%%%%%%%%%%%%%%% checkerboard wedge
% Stimuli specified as array of numbers between -1 (black) and 1 (white), called "A"
R = round(deg2px*par.discrad_deg);  % in pixels

% make mesh...
[x,y] = meshgrid([1:scres(1)]-scres(1)/2,[1:scres(2)]-scres(2)/2);
stimrect = [1 1 scres]-[center center];
Screen('BlendFunction',window,GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

for c=1:par.numconds
    % make Full-screen grating for background
    A = sin(par.spatfreqBG(c)/deg2px*2*pi*(x.*cos(par.oriBG(c))+y.*sin(par.oriBG(c))) + par.spatphaseBG(c)); 
    % cut out the circles for the BG texture
    for n=1:length(par.posx)
        A(find((x-deg2px*par.posx(n)).^2 + (y-deg2px*par.posy(n)).^2 < R^2)) = 0;
    end
    A(1:30,1:30)=0; % cut out the top left for the photodiode
    plane= cat(3,round((A+1)*255/2),255*(A~=0));    % set transparency values - all gray area
    BG(1,c) = Screen('MakeTexture', window, plane);

    % "CENTER" (CNT) Discs
    FULL = sin(par.spatfreqCNT(c)/deg2px*2*pi*(x.*cos(par.oriCNT(c))+y.*sin(par.oriCNT(c))) + par.spatphaseCNT(c)); 
    for n=1:length(par.posx)
        A=FULL;
        A(find((x-deg2px*par.posx(n)).^2 + (y-deg2px*par.posy(n)).^2 > R^2)) = 0;
        plane = cat(3,round((A+1)*255/2),255*(A~=0));
        CNT(n,c) = Screen('MakeTexture', window, plane);
    end
end

%  ************************************************* CODES AND TRIAL SEQUENCE
% trigger codes - can only use these 15: [1 4 5 8 9 12 13 16 17 20 21 24 25 28 29]
par.CD_RESP  = 1;
par.CD_FIX_ON = 4;
par.CD_TGOFF = 5;   % target off
par.CD_TG = 8;   % target   % one for each target type
par.CD_BUTTONS = [12 13];

block = [];
for n=1:length(par.contrastsBG)
    for m=1:length(par.contrastsCNT)
        for c=1:par.numconds
            block = [block repmat([par.contrastsBG(n);par.contrastsCNT(m);c],[1,par.trialsPerCond(c)])]
        end
    end
end
temp = block;
temp = temp(:,randperm(size(temp,2))); 
BGcon = temp(1,:);
CNTcon = temp(2,:);
StimCond = temp(3,:);   % stimulus condition

% test
% Screen('DrawTexture', window, CNT(3,3), [], [1 1 scres],[],[],1);
% Screen('Flip', window); 
% return
% *********************************************************************************** START TASK
% Instructions:
Screen('DrawText', window, 'Just maintain fixation on the central', 0.15*scres(1), 0.25*scres(2), 255);
Screen('DrawText', window, '  spot at all times.', 0.15*scres(1), 0.35*scres(2), 255);
Screen('DrawText', window, 'Press to begin', 0.15*scres(1), 0.55*scres(2), 255);
Screen('Flip', window); 

% Things that we'll save on a trial by trial basis
clear TargOnT RespLR RespT
numResp=1;

% Waits for the user to press a button.
[clicks,x,y,whichButton] = GetClicks(whichScreen,0); tic
if par.useEL, Eyelink('Message', ['TASK_START']); end
if par.recordEEG, sendtrigger(par.CD_RESP,port,SITE,0), end

RespT(1) = GetSecs;
RespLR(1)=whichButton;  if RespLR(numResp)==3, RespLR(numResp)=2; end  % The first response will be the one that sets the task going, after subject reads instructions

%%%%%%%%%%%%%%%%%%%% START TRIALS

% initial lead-in:

Screen('FillRect',window, 255, fixRect);
Screen('Flip', window);
WaitSecs(par.leadintime/1000);

PTlen = round(par.trialdur*par.videoFrate);
framesperflickercycle = round(par.videoFrate./par.FlickF);
ONframes = floor(framesperflickercycle/2);

PT(:,1) = repmat([ones(1,ONframes) zeros(1,framesperflickercycle-ONframes)],1,round(PTlen/framesperflickercycle))';          % fixed stimulus flicker=25hZ
PT(:,2) = PT(:,1);
PT(:,3) = 1-PT(:,1);
PT(:,4) = 1-PT(:,1);
PTsync = PT(:,1);
PTsync(find(PTsync(2:end)==PTsync(1:end-1))+1)=0;

% Start Flicker:
pause = 0; Ptime = GetSecs;
for n=1:par.numtrials
    
    bg = alph(find(alpha2contrast>=BGcon(n),1));    % background
    cnt = alph(find(alpha2contrast>=CNTcon(n),1));    % "center"
    
    % ITI
    Screen('FillRect',window, par.BGcolor, fixRect);
    Screen('Flip', window);
    t_start=GetSecs; t_now=GetSecs;
    while t_now-t_start < par.ITI/1000
        [keyIsDown, secs, keyCode] = KbCheck; % check for keyboard press
        if keyCode(pausekey), pause=1; Ptime = GetSecs; end
        t_now = GetSecs;
    end
    if pause
        while 1
            [keyIsDown, secs, keyCode] = KbCheck; % check for keyboard press
            if keyCode(pausekey) & GetSecs-Ptime > 1, pause=0; Ptime = GetSecs; break; end
        end
    end
    
    % Fixation period
    disp(['TRIAL ' num2str(n) ' OF ' num2str(par.numtrials)])
    Screen('FillRect',window, 255, fixRect);
    if par.recordEEG, sendtrigger(par.CD_FIX_ON,port,SITE,0); end
    if par.useEL, Eyelink('Message', ['TRIAL' num2str(n) 'FIXON' num2str(par.CD_FIX_ON)]); end
    Screen('Flip', window, [], 1);
    t_start=GetSecs; t_now=GetSecs;
    while t_now-t_start < par.fixperiod/1000
        [keyIsDown, secs, keyCode] = KbCheck; % check for keyboard press
        if keyCode(pausekey) & GetSecs-Ptime>1, pause=1; Ptime = GetSecs; end
        t_now = GetSecs;
    end

    if par.recordEEG, sendtrigger(par.CD_TG,port,SITE,0); end
    if par.useEL, Eyelink('Message', ['TRIAL' num2str(n) 'TG' num2str(par.CD_TG)]); end
    TargOnT(n) = GetSecs;
    for p=1:size(PT,1)
        [keyIsDown, secs, keyCode] = KbCheck; % check for keyboard press
        if keyCode(pausekey) & GetSecs-Ptime > 1, pause=1; Ptime = GetSecs; end
        
        Screen('DrawTexture', window, BG(StimCond(n)), [], [center center] + stimrect,[],[],bg);
        for m=1:length(par.posx)
            if PT(p,m)
                Screen('DrawTexture', window, CNT(m,StimCond(n)), [], [center center] + stimrect,[],[],cnt);
            end
        end
        if PTsync(p)
            Screen('FillRect',window, 255, syncRect);
        end
        Screen('FillRect',window, 255, fixRect);
        Screen('Flip', window);
    end
    
end

toc
if par.useEL, 
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    ELdownloadDataFile
end
cleanup

save([par.runID],'TargOnT','BGcon','CNTcon','StimCond','RespT','RespLR','par') 
save par par

