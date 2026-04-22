-- ============================================================
--  ИНФОРМАЦИОННАЯ СИСТЕМА ХОККЕЙНОЙ ЛИГИ
--  MS SQL Server 2019+
--  hockey_league_db.sql
-- ============================================================

USE master;
GO

IF DB_ID(N'HockeyLeague') IS NOT NULL
BEGIN
    ALTER DATABASE HockeyLeague SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HockeyLeague;
END
GO
CREATE DATABASE HockeyLeague COLLATE Cyrillic_General_CI_AS;
GO
USE HockeyLeague;
GO

-- ============================================================
-- 1. СПРАВОЧНИКИ
-- ============================================================

CREATE TABLE Seasons (
    SeasonID   INT           IDENTITY(1,1) PRIMARY KEY,
    Name       NVARCHAR(50)  NOT NULL,          -- "2023/2024"
    StartDate  DATE          NOT NULL,
    EndDate    DATE          NOT NULL,
    IsActive   BIT           NOT NULL DEFAULT 0,
    CONSTRAINT CK_Season_Dates CHECK (EndDate > StartDate)
);
GO

CREATE TABLE Cities (
    CityID   INT           IDENTITY(1,1) PRIMARY KEY,
    Name     NVARCHAR(100) NOT NULL,
    Country  NVARCHAR(100) NOT NULL DEFAULT N'Россия'
);
GO

CREATE TABLE Arenas (
    ArenaID   INT           IDENTITY(1,1) PRIMARY KEY,
    Name      NVARCHAR(150) NOT NULL,
    CityID    INT           NOT NULL REFERENCES Cities(CityID),
    Capacity  INT,
    Address   NVARCHAR(255)
);
GO

CREATE TABLE Teams (
    TeamID       INT           IDENTITY(1,1) PRIMARY KEY,
    Name         NVARCHAR(100) NOT NULL,
    ShortName    NVARCHAR(20),
    CityID       INT           NOT NULL REFERENCES Cities(CityID),
    HomeArenaID  INT           REFERENCES Arenas(ArenaID),
    Founded      INT,
    Budget       DECIMAL(18,2),
    Rating       INT           NOT NULL DEFAULT 0,
    LogoURL      NVARCHAR(255)
);
GO

CREATE TABLE Positions (
    PositionID  INT          IDENTITY(1,1) PRIMARY KEY,
    Name        NVARCHAR(50) NOT NULL,   -- Вратарь, Защитник, Нападающий
    ShortName   NVARCHAR(10)
);
GO

CREATE TABLE CoachRoles (
    RoleID  INT          IDENTITY(1,1) PRIMARY KEY,
    Name    NVARCHAR(100) NOT NULL   -- Главный тренер, Ассистент, Тренер вратарей…
);
GO

CREATE TABLE EventTypes (
    EventTypeID  INT          IDENTITY(1,1) PRIMARY KEY,
    Name         NVARCHAR(100) NOT NULL,  -- Гол, Передача, Удаление, Замена…
    Category     NVARCHAR(50)             -- Goal, Penalty, Substitution, Other
);
GO

-- ============================================================
-- 2. ОСНОВНЫЕ СУЩНОСТИ
-- ============================================================

CREATE TABLE Players (
    PlayerID    INT           IDENTITY(1,1) PRIMARY KEY,
    LastName    NVARCHAR(100) NOT NULL,
    FirstName   NVARCHAR(100) NOT NULL,
    MiddleName  NVARCHAR(100),
    BirthDate   DATE          NOT NULL,
    Citizenship NVARCHAR(100) NOT NULL DEFAULT N'Россия',
    PositionID  INT           NOT NULL REFERENCES Positions(PositionID),
    Height      INT,          -- см
    Weight      INT,          -- кг
    PhotoURL    NVARCHAR(255),
    IsActive    BIT           NOT NULL DEFAULT 1
);
GO

CREATE TABLE Coaches (
    CoachID     INT           IDENTITY(1,1) PRIMARY KEY,
    LastName    NVARCHAR(100) NOT NULL,
    FirstName   NVARCHAR(100) NOT NULL,
    MiddleName  NVARCHAR(100),
    BirthDate   DATE,
    Citizenship NVARCHAR(100) NOT NULL DEFAULT N'Россия',
    PhotoURL    NVARCHAR(255)
);
GO

CREATE TABLE Referees (
    RefereeID  INT           IDENTITY(1,1) PRIMARY KEY,
    LastName   NVARCHAR(100) NOT NULL,
    FirstName  NVARCHAR(100) NOT NULL,
    MiddleName NVARCHAR(100),
    Category   NVARCHAR(50)
);
GO

CREATE TABLE Tournaments (
    TournamentID  INT           IDENTITY(1,1) PRIMARY KEY,
    Name          NVARCHAR(150) NOT NULL,
    SeasonID      INT           NOT NULL REFERENCES Seasons(SeasonID),
    Type          NVARCHAR(20)  NOT NULL
        CONSTRAINT CK_TournType CHECK (Type IN ('Regular','Playoff','Cup')),
    StartDate     DATE,
    EndDate       DATE
);
GO

-- ============================================================
-- 3. СВЯЗЫВАЮЩИЕ ТАБЛИЦЫ (КАДРОВЫЕ)
-- ============================================================

-- Контракты игроков (текущий / исторический состав)
CREATE TABLE Contracts (
    ContractID   INT           IDENTITY(1,1) PRIMARY KEY,
    PlayerID     INT           NOT NULL REFERENCES Players(PlayerID),
    TeamID       INT           NOT NULL REFERENCES Teams(TeamID),
    StartDate    DATE          NOT NULL,
    EndDate      DATE          NOT NULL,
    Salary       DECIMAL(18,2),
    JerseyNumber INT,
    Status       NVARCHAR(20)  NOT NULL DEFAULT 'Active'
        CONSTRAINT CK_ContractStatus CHECK (Status IN ('Active','Expired','Terminated')),
    CONSTRAINT CK_Contract_Dates CHECK (EndDate >= StartDate)
);
GO

-- Тренерские назначения
CREATE TABLE CoachAssignments (
    AssignmentID  INT  IDENTITY(1,1) PRIMARY KEY,
    CoachID       INT  NOT NULL REFERENCES Coaches(CoachID),
    TeamID        INT  NOT NULL REFERENCES Teams(TeamID),
    RoleID        INT  NOT NULL REFERENCES CoachRoles(RoleID),
    SeasonID      INT  REFERENCES Seasons(SeasonID),
    StartDate     DATE NOT NULL,
    EndDate       DATE
);
GO

-- Трансферы
CREATE TABLE Transfers (
    TransferID    INT           IDENTITY(1,1) PRIMARY KEY,
    PlayerID      INT           NOT NULL REFERENCES Players(PlayerID),
    FromTeamID    INT           REFERENCES Teams(TeamID),
    ToTeamID      INT           NOT NULL REFERENCES Teams(TeamID),
    TransferDate  DATE          NOT NULL,
    TransferFee   DECIMAL(18,2),
    TransferType  NVARCHAR(20)  NOT NULL DEFAULT 'Transfer'
        CONSTRAINT CK_TransferType CHECK (TransferType IN ('Transfer','Loan','Free','Draft'))
);
GO

-- ============================================================
-- 4. МАТЧИ И СОБЫТИЯ
-- ============================================================

CREATE TABLE Matches (
    MatchID      INT          IDENTITY(1,1) PRIMARY KEY,
    TournamentID INT          NOT NULL REFERENCES Tournaments(TournamentID),
    HomeTeamID   INT          NOT NULL REFERENCES Teams(TeamID),
    AwayTeamID   INT          NOT NULL REFERENCES Teams(TeamID),
    ArenaID      INT          NOT NULL REFERENCES Arenas(ArenaID),
    MatchDate    DATE         NOT NULL,
    MatchTime    TIME,
    HomeScore    INT          NOT NULL DEFAULT 0,
    AwayScore    INT          NOT NULL DEFAULT 0,
    Status       NVARCHAR(20) NOT NULL DEFAULT 'Scheduled'
        CONSTRAINT CK_MatchStatus CHECK (Status IN ('Scheduled','Live','Finished','Cancelled')),
    Stage        NVARCHAR(50),     -- Regular, 1/8, 1/4, 1/2, Final
    Attendance   INT,
    CONSTRAINT CK_Match_Teams CHECK (HomeTeamID <> AwayTeamID)
);
GO

-- Судейский состав матча
CREATE TABLE MatchReferees (
    MatchRefereeID  INT          IDENTITY(1,1) PRIMARY KEY,
    MatchID         INT          NOT NULL REFERENCES Matches(MatchID),
    RefereeID       INT          NOT NULL REFERENCES Referees(RefereeID),
    Role            NVARCHAR(50)               -- Главный, Линейный 1, Линейный 2
);
GO

-- Заявка на матч (участники)
CREATE TABLE MatchLineups (
    LineupID     INT  IDENTITY(1,1) PRIMARY KEY,
    MatchID      INT  NOT NULL REFERENCES Matches(MatchID),
    PlayerID     INT  NOT NULL REFERENCES Players(PlayerID),
    TeamID       INT  NOT NULL REFERENCES Teams(TeamID),
    JerseyNumber INT,
    IsStarting   BIT  NOT NULL DEFAULT 1,
    CONSTRAINT UQ_Lineup UNIQUE (MatchID, PlayerID)
);
GO

-- Игровые события
CREATE TABLE MatchEvents (
    EventID         INT           IDENTITY(1,1) PRIMARY KEY,
    MatchID         INT           NOT NULL REFERENCES Matches(MatchID),
    EventTypeID     INT           NOT NULL REFERENCES EventTypes(EventTypeID),
    Period          TINYINT,                   -- 1, 2, 3, 4=OT
    GameMinute      INT,
    GameSecond      INT,
    TeamID          INT           REFERENCES Teams(TeamID),
    PlayerID        INT           REFERENCES Players(PlayerID),        -- автор / нарушитель
    AssistPlayer1ID INT           REFERENCES Players(PlayerID),
    AssistPlayer2ID INT           REFERENCES Players(PlayerID),
    PenaltyMinutes  INT,
    Description     NVARCHAR(255)
);
GO

-- ============================================================
-- 5. СТАТИСТИКА
-- ============================================================

CREATE TABLE PlayerSeasonStats (
    StatID         INT           IDENTITY(1,1) PRIMARY KEY,
    PlayerID       INT           NOT NULL REFERENCES Players(PlayerID),
    TeamID         INT           NOT NULL REFERENCES Teams(TeamID),
    SeasonID       INT           NOT NULL REFERENCES Seasons(SeasonID),
    GamesPlayed    INT           NOT NULL DEFAULT 0,
    Goals          INT           NOT NULL DEFAULT 0,
    Assists        INT           NOT NULL DEFAULT 0,
    Points         AS (Goals + Assists) PERSISTED,  -- вычисляемая колонка
    PenaltyMinutes INT           NOT NULL DEFAULT 0,
    PlusMinus      INT           NOT NULL DEFAULT 0,
    Shots          INT           NOT NULL DEFAULT 0,
    -- Для вратарей
    GoalsAgainst   INT           NOT NULL DEFAULT 0,
    SavePct        DECIMAL(5,3)  NOT NULL DEFAULT 0,
    Shutouts       INT           NOT NULL DEFAULT 0,
    CONSTRAINT UQ_PlayerStat UNIQUE (PlayerID, TeamID, SeasonID)
);
GO

CREATE TABLE TeamSeasonStats (
    StatID        INT  IDENTITY(1,1) PRIMARY KEY,
    TeamID        INT  NOT NULL REFERENCES Teams(TeamID),
    SeasonID      INT  NOT NULL REFERENCES Seasons(SeasonID),
    TournamentID  INT  REFERENCES Tournaments(TournamentID),
    GamesPlayed   INT  NOT NULL DEFAULT 0,
    Wins          INT  NOT NULL DEFAULT 0,
    Losses        INT  NOT NULL DEFAULT 0,
    OTLosses      INT  NOT NULL DEFAULT 0,
    Points        INT  NOT NULL DEFAULT 0,
    GoalsFor      INT  NOT NULL DEFAULT 0,
    GoalsAgainst  INT  NOT NULL DEFAULT 0,
    CONSTRAINT UQ_TeamStat UNIQUE (TeamID, SeasonID, TournamentID)
);
GO

-- ============================================================
-- 6. ИНДЕКСЫ
-- ============================================================

CREATE INDEX IX_Players_Position    ON Players(PositionID);
CREATE INDEX IX_Players_Citizenship ON Players(Citizenship);
CREATE INDEX IX_Contracts_Team      ON Contracts(TeamID, Status);
CREATE INDEX IX_Contracts_Player    ON Contracts(PlayerID);
CREATE INDEX IX_Matches_Date        ON Matches(MatchDate);
CREATE INDEX IX_Matches_Tournament  ON Matches(TournamentID);
CREATE INDEX IX_Matches_HomeTeam    ON Matches(HomeTeamID);
CREATE INDEX IX_Matches_AwayTeam    ON Matches(AwayTeamID);
CREATE INDEX IX_Matches_Arena       ON Matches(ArenaID);
CREATE INDEX IX_Events_Match        ON MatchEvents(MatchID);
CREATE INDEX IX_Events_Player       ON MatchEvents(PlayerID);
CREATE INDEX IX_PSS_Season          ON PlayerSeasonStats(SeasonID);
CREATE INDEX IX_PSS_Player          ON PlayerSeasonStats(PlayerID);
CREATE INDEX IX_TSS_Season          ON TeamSeasonStats(SeasonID);
CREATE INDEX IX_Transfers_Player    ON Transfers(PlayerID);
CREATE INDEX IX_Transfers_Date      ON Transfers(TransferDate);
GO

-- ============================================================
-- 7. ПРЕДСТАВЛЕНИЯ (VIEW)
-- ============================================================

-- 7.1 Текущий состав команды (активные контракты)
CREATE VIEW vw_CurrentRoster AS
SELECT
    c.TeamID,
    t.Name              AS TeamName,
    p.PlayerID,
    p.LastName + N' ' + p.FirstName + ISNULL(N' ' + p.MiddleName, N'') AS FullName,
    p.BirthDate,
    DATEDIFF(YEAR, p.BirthDate, GETDATE()) AS Age,
    p.Citizenship,
    pos.Name            AS Position,
    c.JerseyNumber,
    c.Salary,
    c.EndDate           AS ContractEnd
FROM Contracts c
JOIN Players p  ON p.PlayerID  = c.PlayerID
JOIN Teams   t  ON t.TeamID    = c.TeamID
JOIN Positions pos ON pos.PositionID = p.PositionID
WHERE c.Status = 'Active'
  AND c.StartDate <= CAST(GETDATE() AS DATE)
  AND c.EndDate   >= CAST(GETDATE() AS DATE);
GO

-- 7.2 Турнирная таблица по турниру
CREATE VIEW vw_Standings AS
SELECT
    tss.SeasonID,       -- ДОБАВЛЕНО: ID сезона для фильтрации в процедурах
    tss.TournamentID,
    tn.Name             AS TournamentName,
    s.Name              AS SeasonName,
    tss.TeamID,
    t.Name              AS TeamName,
    t.ShortName,
    tss.GamesPlayed,
    tss.Wins,
    tss.Losses,
    tss.OTLosses,
    tss.Points,
    tss.GoalsFor,
    tss.GoalsAgainst,
    tss.GoalsFor - tss.GoalsAgainst AS GoalDiff,
    RANK() OVER (PARTITION BY tss.TournamentID ORDER BY tss.Points DESC,
                 tss.GoalsFor - tss.GoalsAgainst DESC) AS TablePosition
FROM TeamSeasonStats tss
JOIN Teams       t  ON t.TeamID       = tss.TeamID
JOIN Seasons     s  ON s.SeasonID     = tss.SeasonID
JOIN Tournaments tn ON tn.TournamentID = tss.TournamentID;
GO

-- 7.3 Бомбардиры (суммарно голы + передачи)
CREATE VIEW vw_TopScorers AS
SELECT
    pss.SeasonID,
    s.Name              AS SeasonName,
    pss.PlayerID,
    p.LastName + N' ' + p.FirstName AS FullName,
    pos.Name            AS Position,
    pss.TeamID,
    t.Name              AS TeamName,
    pss.GamesPlayed,
    pss.Goals,
    pss.Assists,
    pss.Points,
    pss.PenaltyMinutes,
    pss.PlusMinus,
    pss.Shots           -- ДОБАВЛЕНО: Броски для корректной работы сортировки
FROM PlayerSeasonStats pss
JOIN Players   p   ON p.PlayerID    = pss.PlayerID
JOIN Teams     t   ON t.TeamID      = pss.TeamID
JOIN Seasons   s   ON s.SeasonID    = pss.SeasonID
JOIN Positions pos ON pos.PositionID = p.PositionID;
GO

-- 7.4 Сводка по матчам
CREATE VIEW vw_MatchResults AS
SELECT
    m.MatchID,
    tn.TournamentID,
    tn.Name             AS TournamentName,
    tn.Type             AS TournamentType,
    s.SeasonID,
    s.Name              AS SeasonName,
    m.Stage,
    m.MatchDate,
    m.MatchTime,
    a.ArenaID,
    a.Name              AS ArenaName,
    ci.Name             AS ArenaCity,
    m.HomeTeamID,
    ht.Name             AS HomeTeam,
    m.AwayTeamID,
    at2.Name            AS AwayTeam,
    m.HomeScore,
    m.AwayScore,
    m.Status,
    m.Attendance,
    CASE
        WHEN m.HomeScore > m.AwayScore THEN m.HomeTeamID
        WHEN m.AwayScore > m.HomeScore THEN m.AwayTeamID
        ELSE NULL
    END                 AS WinnerTeamID
FROM Matches m
JOIN Tournaments tn ON tn.TournamentID = m.TournamentID
JOIN Seasons     s  ON s.SeasonID      = tn.SeasonID
JOIN Arenas      a  ON a.ArenaID       = m.ArenaID
JOIN Cities      ci ON ci.CityID       = a.CityID
JOIN Teams       ht ON ht.TeamID       = m.HomeTeamID
JOIN Teams       at2 ON at2.TeamID     = m.AwayTeamID;
GO

-- 7.5 Активный тренерский штаб
CREATE VIEW vw_ActiveCoaches AS
SELECT
    ca.TeamID,
    t.Name              AS TeamName,
    ca.SeasonID,
    s.Name              AS SeasonName,
    c.CoachID,
    c.LastName + N' ' + c.FirstName AS FullName,
    c.Citizenship,
    cr.Name             AS Role
FROM CoachAssignments ca
JOIN Coaches    c  ON c.CoachID  = ca.CoachID
JOIN Teams      t  ON t.TeamID   = ca.TeamID
JOIN CoachRoles cr ON cr.RoleID  = ca.RoleID
LEFT JOIN Seasons s ON s.SeasonID = ca.SeasonID
WHERE ca.EndDate IS NULL OR ca.EndDate >= CAST(GETDATE() AS DATE);
GO

-- 7.6 Полная лента игровых событий матча
CREATE VIEW vw_MatchEventsFull AS
SELECT
    e.EventID,
    e.MatchID,
    et.Name             AS EventType,
    et.Category,
    e.Period,
    e.GameMinute,
    e.GameSecond,
    tm.Name             AS Team,
    p.LastName + N' ' + p.FirstName  AS PlayerName,
    a1.LastName + N' ' + a1.FirstName AS Assist1,
    a2.LastName + N' ' + a2.FirstName AS Assist2,
    e.PenaltyMinutes,
    e.Description
FROM MatchEvents e
JOIN EventTypes et ON et.EventTypeID = e.EventTypeID
LEFT JOIN Teams   tm ON tm.TeamID    = e.TeamID
LEFT JOIN Players p  ON p.PlayerID   = e.PlayerID
LEFT JOIN Players a1 ON a1.PlayerID  = e.AssistPlayer1ID
LEFT JOIN Players a2 ON a2.PlayerID  = e.AssistPlayer2ID;
GO

-- ============================================================
-- 8. ХРАНИМЫЕ ПРОЦЕДУРЫ
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 8.1  Список команд лиги за сезон
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTeamsBySeason
    @SeasonID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Seasons WHERE SeasonID = @SeasonID)
    BEGIN
        RAISERROR(N'Сезон с ID=%d не найден.', 16, 1, @SeasonID);
        RETURN;
    END

    SELECT
        t.TeamID,
        t.Name          AS TeamName,
        t.ShortName,
        ci.Name         AS City,
        a.Name          AS HomeArena,
        t.Rating,
        t.Budget,
        COUNT(DISTINCT c.PlayerID) AS RosterSize
    FROM Teams t
    JOIN Cities ci ON ci.CityID = t.CityID
    LEFT JOIN Arenas a ON a.ArenaID = t.HomeArenaID
    -- команда участвует в сезоне, если у неё есть матчи в турнирах этого сезона
    INNER JOIN Tournaments tn ON tn.SeasonID = @SeasonID
    INNER JOIN Matches m
        ON m.TournamentID = tn.TournamentID
        AND (m.HomeTeamID = t.TeamID OR m.AwayTeamID = t.TeamID)
    LEFT JOIN Contracts c
        ON c.TeamID = t.TeamID AND c.Status = 'Active'
    GROUP BY t.TeamID, t.Name, t.ShortName, ci.Name, a.Name, t.Rating, t.Budget
    ORDER BY t.Name;

    SELECT COUNT(DISTINCT t2.TeamID) AS TotalTeams
    FROM Teams t2
    JOIN Tournaments tn2 ON tn2.SeasonID = @SeasonID
    JOIN Matches m2 ON m2.TournamentID = tn2.TournamentID
        AND (m2.HomeTeamID = t2.TeamID OR m2.AwayTeamID = t2.TeamID);
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.2  Игроки команды с фильтрацией
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetPlayersByTeam
    @TeamID      INT,
    @PositionID  INT       = NULL,   -- необязательно
    @Citizenship NVARCHAR(100) = NULL,
    @MinAge      INT       = NULL,
    @MaxAge      INT       = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.PlayerID,
        r.FullName,
        r.Age,
        r.BirthDate,
        r.Citizenship,
        r.Position,
        r.JerseyNumber,
        r.Salary,
        r.ContractEnd
    FROM vw_CurrentRoster r
    WHERE r.TeamID = @TeamID
      AND (@PositionID  IS NULL OR r.Position = (SELECT Name FROM Positions WHERE PositionID = @PositionID))
      AND (@Citizenship IS NULL OR r.Citizenship = @Citizenship)
      AND (@MinAge      IS NULL OR r.Age >= @MinAge)
      AND (@MaxAge      IS NULL OR r.Age <= @MaxAge)
    ORDER BY r.Position, r.FullName;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.3  Статистика игрока за сезон
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetPlayerSeasonStats
    @PlayerID INT,
    @SeasonID INT = NULL   -- NULL = все сезоны
AS
BEGIN
    SET NOCOUNT ON;

    -- Личная карточка
    SELECT
        p.PlayerID,
        p.LastName + N' ' + p.FirstName + ISNULL(N' ' + p.MiddleName, N'') AS FullName,
        p.BirthDate,
        DATEDIFF(YEAR, p.BirthDate, GETDATE()) AS Age,
        p.Citizenship,
        pos.Name AS Position,
        p.Height, p.Weight,
        p.PhotoURL
    FROM Players p
    JOIN Positions pos ON pos.PositionID = p.PositionID
    WHERE p.PlayerID = @PlayerID;

    -- Статистика по сезонам
    SELECT
        s.Name      AS SeasonName,
        t.Name      AS TeamName,
        pss.GamesPlayed,
        pss.Goals,
        pss.Assists,
        pss.Points,
        pss.PenaltyMinutes,
        pss.PlusMinus,
        pss.Shots,
        pss.GoalsAgainst,
        pss.SavePct,
        pss.Shutouts
    FROM PlayerSeasonStats pss
    JOIN Seasons s ON s.SeasonID = pss.SeasonID
    JOIN Teams   t ON t.TeamID   = pss.TeamID
    WHERE pss.PlayerID = @PlayerID
      AND (@SeasonID IS NULL OR pss.SeasonID = @SeasonID)
    ORDER BY s.StartDate DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.4  Матчи команды за период
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTeamMatches
    @TeamID    INT,
    @DateFrom  DATE = NULL,
    @DateTo    DATE = NULL,
    @SeasonID  INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        mr.MatchID,
        mr.TournamentName,
        mr.TournamentType,
        mr.SeasonName,
        mr.Stage,
        mr.MatchDate,
        mr.MatchTime,
        mr.ArenaName,
        mr.ArenaCity,
        mr.HomeTeam,
        mr.AwayTeam,
        mr.HomeScore,
        mr.AwayScore,
        mr.Status,
        CASE
            WHEN mr.WinnerTeamID = @TeamID THEN N'Победа'
            WHEN mr.WinnerTeamID IS NULL AND mr.Status = 'Finished' THEN N'Ничья'
            WHEN mr.WinnerTeamID IS NOT NULL AND mr.WinnerTeamID <> @TeamID THEN N'Поражение'
            ELSE N'—'
        END AS Result
    FROM vw_MatchResults mr
    WHERE (mr.HomeTeamID = @TeamID OR mr.AwayTeamID = @TeamID)
      AND (@DateFrom IS NULL OR mr.MatchDate >= @DateFrom)
      AND (@DateTo   IS NULL OR mr.MatchDate <= @DateTo)
      AND (@SeasonID IS NULL OR mr.SeasonID = @SeasonID)
    ORDER BY mr.MatchDate DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.5  Результаты встреч между двумя командами (очные)
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetHeadToHead
    @Team1ID  INT,
    @Team2ID  INT,
    @SeasonID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        mr.MatchID,
        mr.SeasonName,
        mr.TournamentName,
        mr.Stage,
        mr.MatchDate,
        mr.ArenaName,
        mr.HomeTeam,
        mr.AwayTeam,
        mr.HomeScore,
        mr.AwayScore,
        mr.Status
    FROM vw_MatchResults mr
    WHERE (
            (mr.HomeTeamID = @Team1ID AND mr.AwayTeamID = @Team2ID)
         OR (mr.HomeTeamID = @Team2ID AND mr.AwayTeamID = @Team1ID)
          )
      AND (@SeasonID IS NULL OR mr.SeasonID = @SeasonID)
    ORDER BY mr.MatchDate DESC;

    -- Сводка побед/поражений
    SELECT
        SUM(CASE WHEN mr2.WinnerTeamID = @Team1ID THEN 1 ELSE 0 END) AS Team1Wins,
        SUM(CASE WHEN mr2.WinnerTeamID = @Team2ID THEN 1 ELSE 0 END) AS Team2Wins,
        SUM(CASE WHEN mr2.WinnerTeamID IS NULL AND mr2.Status = 'Finished' THEN 1 ELSE 0 END) AS Draws
    FROM vw_MatchResults mr2
    WHERE (
            (mr2.HomeTeamID = @Team1ID AND mr2.AwayTeamID = @Team2ID)
         OR (mr2.HomeTeamID = @Team2ID AND mr2.AwayTeamID = @Team1ID)
          )
      AND mr2.Status = 'Finished'
      AND (@SeasonID IS NULL OR mr2.SeasonID = @SeasonID);
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.6  Турнирная таблица
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetStandings
    @TournamentID INT = NULL,
    @SeasonID     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM vw_Standings
    WHERE (@TournamentID IS NULL OR TournamentID = @TournamentID)
      AND (@SeasonID     IS NULL OR SeasonID     = @SeasonID)
    ORDER BY TournamentID, TablePosition;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.7  Лучшие игроки по выбранной статистике
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTopPlayers
    @SeasonID  INT,
    @StatField NVARCHAR(20) = 'Points',  -- Goals | Assists | Points | Shots
    @TopN      INT          = 10,
    @TeamID    INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        ts.PlayerID,
        ts.FullName,
        ts.Position,
        ts.TeamName,
        ts.SeasonName,
        ts.GamesPlayed,
        ts.Goals,
        ts.Assists,
        ts.Points,
        ts.PenaltyMinutes,
        ts.PlusMinus,
        ts.Shots,
        RANK() OVER (ORDER BY
            CASE @StatField
                WHEN 'Goals'   THEN ts.Goals
                WHEN 'Assists' THEN ts.Assists
                WHEN 'Shots'   THEN ts.Shots
                ELSE ts.Points
            END DESC
        ) AS Rank
    FROM vw_TopScorers ts
    WHERE ts.SeasonID = @SeasonID
      AND (@TeamID IS NULL OR ts.TeamID = @TeamID)
    ORDER BY
        CASE @StatField
            WHEN 'Goals'   THEN ts.Goals
            WHEN 'Assists' THEN ts.Assists
            WHEN 'Shots'   THEN ts.Shots
            ELSE ts.Points
        END DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.8  Игроки с максимальным штрафным временем
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetMostPenalizedPlayers
    @SeasonID INT,
    @TopN     INT = 10,
    @TeamID   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        ts.PlayerID,
        ts.FullName,
        ts.Position,
        ts.TeamName,
        ts.SeasonName,
        ts.GamesPlayed,
        ts.PenaltyMinutes,
        ts.Goals,
        ts.Assists,
        ts.Points
    FROM vw_TopScorers ts
    WHERE ts.SeasonID = @SeasonID
      AND (@TeamID IS NULL OR ts.TeamID = @TeamID)
    ORDER BY ts.PenaltyMinutes DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.9  Матчи по арене
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetMatchesByArena
    @ArenaID   INT,
    @DateFrom  DATE = NULL,
    @DateTo    DATE = NULL,
    @SeasonID  INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        mr.MatchID,
        mr.SeasonName,
        mr.TournamentName,
        mr.Stage,
        mr.MatchDate,
        mr.MatchTime,
        mr.HomeTeam,
        mr.AwayTeam,
        mr.HomeScore,
        mr.AwayScore,
        mr.Status,
        mr.Attendance
    FROM vw_MatchResults mr
    WHERE mr.ArenaID = @ArenaID
      AND (@DateFrom IS NULL OR mr.MatchDate >= @DateFrom)
      AND (@DateTo   IS NULL OR mr.MatchDate <= @DateTo)
      AND (@SeasonID IS NULL OR mr.SeasonID  = @SeasonID)
    ORDER BY mr.MatchDate DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.10  Тренерский штаб команды
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTeamCoaches
    @TeamID   INT,
    @SeasonID INT = NULL,
    @Current  BIT = 1    -- 1 = только действующие
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ca.AssignmentID,
        c.CoachID,
        c.LastName + N' ' + c.FirstName + ISNULL(N' ' + c.MiddleName, N'') AS FullName,
        c.BirthDate,
        DATEDIFF(YEAR, c.BirthDate, GETDATE()) AS Age,
        c.Citizenship,
        cr.Name         AS Role,
        s.Name          AS Season,
        ca.StartDate,
        ca.EndDate
    FROM CoachAssignments ca
    JOIN Coaches    c  ON c.CoachID  = ca.CoachID
    JOIN CoachRoles cr ON cr.RoleID  = ca.RoleID
    LEFT JOIN Seasons s ON s.SeasonID = ca.SeasonID
    WHERE ca.TeamID = @TeamID
      AND (@SeasonID IS NULL OR ca.SeasonID = @SeasonID)
      AND (@Current  = 0 OR (ca.EndDate IS NULL OR ca.EndDate >= CAST(GETDATE() AS DATE)))
    ORDER BY cr.Name;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.11  Список трансферов
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTransfers
    @DateFrom    DATE         = NULL,
    @DateTo      DATE         = NULL,
    @TeamID      INT          = NULL,   -- фильтр по принимающей или отдающей команде
    @PlayerID    INT          = NULL,
    @TransferType NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tr.TransferID,
        tr.TransferDate,
        tr.TransferType,
        p.PlayerID,
        p.LastName + N' ' + p.FirstName AS PlayerName,
        pos.Name        AS Position,
        tf.Name         AS FromTeam,
        tt.Name         AS ToTeam,
        tr.TransferFee
    FROM Transfers tr
    JOIN Players  p   ON p.PlayerID  = tr.PlayerID
    JOIN Positions pos ON pos.PositionID = p.PositionID
    LEFT JOIN Teams tf ON tf.TeamID  = tr.FromTeamID
    JOIN Teams     tt ON tt.TeamID   = tr.ToTeamID
    WHERE (@DateFrom IS NULL OR tr.TransferDate >= @DateFrom)
      AND (@DateTo   IS NULL OR tr.TransferDate <= @DateTo)
      AND (@TeamID   IS NULL OR tr.FromTeamID = @TeamID OR tr.ToTeamID = @TeamID)
      AND (@PlayerID IS NULL OR tr.PlayerID = @PlayerID)
      AND (@TransferType IS NULL OR tr.TransferType = @TransferType)
    ORDER BY tr.TransferDate DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.12  Игроки, сменившие команду (за период / сезон)
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTransferredPlayers
    @SeasonID INT  = NULL,
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Определяем диапазон дат через сезон, если передан
    DECLARE @From DATE = @DateFrom;
    DECLARE @To   DATE = @DateTo;

    IF @SeasonID IS NOT NULL AND @DateFrom IS NULL
        SELECT @From = StartDate, @To = EndDate FROM Seasons WHERE SeasonID = @SeasonID;

    SELECT DISTINCT
        p.PlayerID,
        p.LastName + N' ' + p.FirstName AS PlayerName,
        pos.Name        AS Position,
        p.Citizenship,
        COUNT(tr.TransferID) OVER (PARTITION BY p.PlayerID) AS TransferCount
    FROM Transfers tr
    JOIN Players  p   ON p.PlayerID  = tr.PlayerID
    JOIN Positions pos ON pos.PositionID = p.PositionID
    WHERE (@From IS NULL OR tr.TransferDate >= @From)
      AND (@To   IS NULL OR tr.TransferDate <= @To)
    ORDER BY TransferCount DESC, PlayerName;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.13  Статистика команды
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetTeamStats
    @TeamID   INT,
    @SeasonID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Общая статистика из агрегата
    SELECT
        tss.SeasonID,
        s.Name      AS SeasonName,
        tn.Name     AS Tournament,
        tss.GamesPlayed,
        tss.Wins,
        tss.Losses,
        tss.OTLosses,
        tss.Points,
        tss.GoalsFor,
        tss.GoalsAgainst,
        tss.GoalsFor - tss.GoalsAgainst AS GoalDiff,
        CAST(tss.Wins AS DECIMAL) / NULLIF(tss.GamesPlayed,0) * 100 AS WinPct
    FROM TeamSeasonStats tss
    JOIN Seasons     s  ON s.SeasonID     = tss.SeasonID
    JOIN Tournaments tn ON tn.TournamentID = tss.TournamentID
    WHERE tss.TeamID = @TeamID
      AND (@SeasonID IS NULL OR tss.SeasonID = @SeasonID)
    ORDER BY s.StartDate DESC;

    -- Топ-3 бомбардира команды за запрошенный сезон
    IF @SeasonID IS NOT NULL
    BEGIN
        SELECT TOP 3
            ts.PlayerID,
            ts.FullName,
            ts.Position,
            ts.GamesPlayed,
            ts.Goals,
            ts.Assists,
            ts.Points
        FROM vw_TopScorers ts
        WHERE ts.TeamID   = @TeamID
          AND ts.SeasonID = @SeasonID
        ORDER BY ts.Points DESC;
    END
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.14  Результативные матчи (по суммарному числу голов)
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetHighScoringMatches
    @SeasonID    INT  = NULL,
    @MinGoals    INT  = 6,
    @TopN        INT  = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        mr.MatchID,
        mr.SeasonName,
        mr.TournamentName,
        mr.Stage,
        mr.MatchDate,
        mr.ArenaName,
        mr.HomeTeam,
        mr.AwayTeam,
        mr.HomeScore,
        mr.AwayScore,
        mr.HomeScore + mr.AwayScore AS TotalGoals
    FROM vw_MatchResults mr
    WHERE mr.Status = 'Finished'
      AND mr.HomeScore + mr.AwayScore >= @MinGoals
      AND (@SeasonID IS NULL OR mr.SeasonID = @SeasonID)
    ORDER BY TotalGoals DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 8.15  Участники матча
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetMatchParticipants
    @MatchID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Общая информация о матче
    SELECT *
    FROM vw_MatchResults
    WHERE MatchID = @MatchID;

    -- Состав команд
    SELECT
        ml.TeamID,
        t.Name          AS TeamName,
        ml.PlayerID,
        p.LastName + N' ' + p.FirstName AS PlayerName,
        pos.Name        AS Position,
        ml.JerseyNumber,
        ml.IsStarting
    FROM MatchLineups ml
    JOIN Players   p   ON p.PlayerID   = ml.PlayerID
    JOIN Positions pos ON pos.PositionID = p.PositionID
    JOIN Teams     t   ON t.TeamID      = ml.TeamID
    WHERE ml.MatchID = @MatchID
    ORDER BY ml.TeamID, ml.IsStarting DESC, pos.Name;

    -- Судейский состав
    SELECT
        mr.Role,
        r.LastName + N' ' + r.FirstName AS RefereeName,
        r.Category
    FROM MatchReferees mr
    JOIN Referees r ON r.RefereeID = mr.RefereeID
    WHERE mr.MatchID = @MatchID;

    -- Хронология событий
    SELECT *
    FROM vw_MatchEventsFull
    WHERE MatchID = @MatchID
    ORDER BY Period, GameMinute, GameSecond;
END;
GO

-- ============================================================
-- 9. АНАЛИТИЧЕСКИЕ ОТЧЁТЫ
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 9.1  Отчёт по сезону
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetSeasonReport
    @SeasonID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Мета-информация сезона
    SELECT
        s.SeasonID,
        s.Name,
        s.StartDate,
        s.EndDate,
        COUNT(DISTINCT m.MatchID)    AS TotalMatches,
        COUNT(DISTINCT CASE WHEN m.Status = 'Finished' THEN m.MatchID END) AS PlayedMatches,
        SUM(m.HomeScore + m.AwayScore) AS TotalGoals,
        AVG(CAST(m.HomeScore + m.AwayScore AS FLOAT)) AS AvgGoalsPerMatch,
        SUM(m.Attendance)            AS TotalAttendance
    FROM Seasons s
    LEFT JOIN Tournaments tn ON tn.SeasonID = s.SeasonID
    LEFT JOIN Matches     m  ON m.TournamentID = tn.TournamentID
    WHERE s.SeasonID = @SeasonID
    GROUP BY s.SeasonID, s.Name, s.StartDate, s.EndDate;

    -- Турнирная таблица
    SELECT *
    FROM vw_Standings
    WHERE SeasonID = @SeasonID
    ORDER BY TournamentID, TablePosition;

    -- Лучшие бомбардиры сезона (топ-10)
    SELECT TOP 10 *
    FROM vw_TopScorers
    WHERE SeasonID = @SeasonID
    ORDER BY Points DESC, Goals DESC;

    -- Лучшие бомбардиры по штрафам (топ-10)
    SELECT TOP 10 *
    FROM vw_TopScorers
    WHERE SeasonID = @SeasonID
    ORDER BY PenaltyMinutes DESC;

    -- Самые результативные матчи (топ-5)
    SELECT TOP 5
        mr.MatchDate, mr.TournamentName, mr.Stage,
        mr.HomeTeam, mr.HomeScore, mr.AwayScore, mr.AwayTeam,
        mr.HomeScore + mr.AwayScore AS TotalGoals
    FROM vw_MatchResults mr
    WHERE mr.SeasonID = @SeasonID AND mr.Status = 'Finished'
    ORDER BY TotalGoals DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 9.2  Карточка игрока (полное досье)
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetPlayerCard
    @PlayerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Личные данные
    SELECT
        p.PlayerID,
        p.LastName + N' ' + p.FirstName + ISNULL(N' ' + p.MiddleName, N'') AS FullName,
        p.BirthDate,
        DATEDIFF(YEAR, p.BirthDate, GETDATE()) AS Age,
        p.Citizenship,
        pos.Name AS Position,
        p.Height, p.Weight,
        p.PhotoURL
    FROM Players p
    JOIN Positions pos ON pos.PositionID = p.PositionID
    WHERE p.PlayerID = @PlayerID;

    -- Текущий контракт
    SELECT TOP 1
        t.Name  AS Team,
        c.JerseyNumber,
        c.Salary,
        c.StartDate,
        c.EndDate
    FROM Contracts c
    JOIN Teams t ON t.TeamID = c.TeamID
    WHERE c.PlayerID = @PlayerID AND c.Status = 'Active'
    ORDER BY c.StartDate DESC;

    -- Статистика по всем сезонам
    SELECT
        s.Name AS Season, t.Name AS Team,
        pss.GamesPlayed, pss.Goals, pss.Assists, pss.Points,
        pss.PenaltyMinutes, pss.PlusMinus, pss.Shots,
        pss.GoalsAgainst, pss.SavePct, pss.Shutouts
    FROM PlayerSeasonStats pss
    JOIN Seasons s ON s.SeasonID = pss.SeasonID
    JOIN Teams   t ON t.TeamID   = pss.TeamID
    WHERE pss.PlayerID = @PlayerID
    ORDER BY s.StartDate DESC;

    -- История трансферов
    SELECT
        tr.TransferDate,
        tr.TransferType,
        tf.Name AS FromTeam,
        tt.Name AS ToTeam,
        tr.TransferFee
    FROM Transfers tr
    LEFT JOIN Teams tf ON tf.TeamID = tr.FromTeamID
    JOIN Teams     tt ON tt.TeamID  = tr.ToTeamID
    WHERE tr.PlayerID = @PlayerID
    ORDER BY tr.TransferDate;

    -- Последние 5 матчей с участием игрока
    SELECT TOP 5
        mr.MatchDate,
        mr.TournamentName,
        mr.HomeTeam,
        mr.HomeScore, mr.AwayScore,
        mr.AwayTeam,
        mr.Status
    FROM MatchLineups ml
    JOIN vw_MatchResults mr ON mr.MatchID = ml.MatchID
    WHERE ml.PlayerID = @PlayerID
    ORDER BY mr.MatchDate DESC;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 9.3  Отчёт по матчу
-- ────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_GetMatchReport
    @MatchID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Общая информация
    SELECT
        mr.MatchID,
        mr.TournamentName,
        mr.TournamentType,
        mr.SeasonName,
        mr.Stage,
        mr.MatchDate,
        mr.MatchTime,
        mr.ArenaName,
        mr.ArenaCity,
        mr.HomeTeam,
        mr.AwayTeam,
        mr.HomeScore,
        mr.AwayScore,
        mr.Status,
        mr.Attendance
    FROM vw_MatchResults mr
    WHERE mr.MatchID = @MatchID;

    -- Шайбы (голы) по периодам
    SELECT
        mef.Period,
        mef.GameMinute,
        mef.GameSecond,
        mef.Team,
        mef.PlayerName,
        mef.Assist1,
        mef.Assist2
    FROM vw_MatchEventsFull mef
    WHERE mef.MatchID = @MatchID AND mef.Category = 'Goal'
    ORDER BY mef.Period, mef.GameMinute, mef.GameSecond;

    -- Счёт по периодам (агрегат голов)
    SELECT
        e.Period,
        tm.HomeTeamID,
        SUM(CASE WHEN e.TeamID = m.HomeTeamID THEN 1 ELSE 0 END) AS HomeGoals,
        SUM(CASE WHEN e.TeamID = m.AwayTeamID THEN 1 ELSE 0 END) AS AwayGoals
    FROM MatchEvents e
    JOIN Matches m ON m.MatchID = e.MatchID
    JOIN EventTypes et ON et.EventTypeID = e.EventTypeID
    CROSS JOIN (SELECT HomeTeamID FROM Matches WHERE MatchID = @MatchID) tm
    WHERE e.MatchID = @MatchID AND et.Category = 'Goal'
    GROUP BY e.Period, tm.HomeTeamID, m.HomeTeamID;

    -- Удаления
    SELECT
        mef.Period,
        mef.GameMinute,
        mef.Team,
        mef.PlayerName,
        mef.PenaltyMinutes,
        mef.Description
    FROM vw_MatchEventsFull mef
    WHERE mef.MatchID = @MatchID AND mef.Category = 'Penalty'
    ORDER BY mef.Period, mef.GameMinute;

    -- Судьи
    SELECT r.LastName + N' ' + r.FirstName AS RefereeName, mr2.Role
    FROM MatchReferees mr2
    JOIN Referees r ON r.RefereeID = mr2.RefereeID
    WHERE mr2.MatchID = @MatchID;
END;
GO

-- ============================================================
-- 10. ТРИГГЕРЫ
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 10.1  После вставки события-гола — обновляем счёт матча
-- ────────────────────────────────────────────────────────────
CREATE TRIGGER tr_MatchEvents_AfterGoal
ON MatchEvents
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE m
    SET
        m.HomeScore = (
            SELECT COUNT(*)
            FROM MatchEvents e
            JOIN EventTypes et ON et.EventTypeID = e.EventTypeID
            WHERE e.MatchID = m.MatchID
              AND et.Category = 'Goal'
              AND e.TeamID   = m.HomeTeamID
        ),
        m.AwayScore = (
            SELECT COUNT(*)
            FROM MatchEvents e
            JOIN EventTypes et ON et.EventTypeID = e.EventTypeID
            WHERE e.MatchID = m.MatchID
              AND et.Category = 'Goal'
              AND e.TeamID   = m.AwayTeamID
        )
    FROM Matches m
    INNER JOIN inserted i ON i.MatchID = m.MatchID
    WHERE i.EventTypeID IN (SELECT EventTypeID FROM EventTypes WHERE Category = 'Goal');
END;
GO

-- ────────────────────────────────────────────────────────────
-- 10.2  При добавлении трансфера — закрыть предыдущий контракт
-- ────────────────────────────────────────────────────────────
CREATE TRIGGER tr_Transfers_CloseOldContract
ON Transfers
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Contracts
    SET Status  = 'Terminated',
        EndDate = i.TransferDate
    FROM Contracts c
    INNER JOIN inserted i ON i.PlayerID  = c.PlayerID
                          AND i.FromTeamID = c.TeamID
    WHERE c.Status = 'Active'
      AND c.EndDate >= i.TransferDate;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 10.3  Запрет изменения счёта финишированного матча вручную
-- ────────────────────────────────────────────────────────────
CREATE TRIGGER tr_Matches_PreventScoreEdit
ON Matches
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted  d ON d.MatchID = i.MatchID
        WHERE d.Status = 'Finished'
          AND (d.HomeScore <> i.HomeScore OR d.AwayScore <> i.AwayScore)
    )
    BEGIN
        RAISERROR(N'Нельзя изменить счёт завершённого матча.', 16, 1);
        RETURN;
    END

    UPDATE m
    SET
        TournamentID = i.TournamentID,
        HomeTeamID   = i.HomeTeamID,
        AwayTeamID   = i.AwayTeamID,
        ArenaID      = i.ArenaID,
        MatchDate    = i.MatchDate,
        MatchTime    = i.MatchTime,
        HomeScore    = i.HomeScore,
        AwayScore    = i.AwayScore,
        Status       = i.Status,
        Stage        = i.Stage,
        Attendance   = i.Attendance
    FROM Matches m
    JOIN inserted i ON i.MatchID = m.MatchID;
END;
GO

-- ────────────────────────────────────────────────────────────
-- 10.4  При завершении матча (Status→Finished) —
--       автоматически пересчитать TeamSeasonStats
-- ────────────────────────────────────────────────────────────
CREATE TRIGGER tr_Matches_UpdateTeamStats
ON Matches
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Обрабатываем только переход в статус Finished
    IF NOT EXISTS (
        SELECT 1 FROM inserted i
        JOIN deleted d ON d.MatchID = i.MatchID
        WHERE i.Status = 'Finished' AND d.Status <> 'Finished'
    ) RETURN;

    -- Пересчёт для каждой затронутой (команда, турнир, сезон)
    WITH MatchAgg AS (
        SELECT
            tm.TeamID,
            m.TournamentID,
            tn.SeasonID,
            COUNT(*)  AS GP,
            SUM(CASE WHEN
                  (m.HomeTeamID = tm.TeamID AND m.HomeScore > m.AwayScore)
               OR (m.AwayTeamID = tm.TeamID AND m.AwayScore > m.HomeScore)
                THEN 1 ELSE 0 END) AS W,
            SUM(CASE WHEN m.HomeScore = m.AwayScore THEN 1 ELSE 0 END) AS OTL,
            SUM(CASE WHEN
                  (m.HomeTeamID = tm.TeamID AND m.HomeScore < m.AwayScore)
               OR (m.AwayTeamID = tm.TeamID AND m.AwayScore < m.HomeScore)
                THEN 1 ELSE 0 END) AS L,
            SUM(CASE WHEN m.HomeTeamID = tm.TeamID THEN m.HomeScore ELSE m.AwayScore END) AS GF,
            SUM(CASE WHEN m.HomeTeamID = tm.TeamID THEN m.AwayScore ELSE m.HomeScore END) AS GA
        FROM inserted i
        JOIN Matches m ON m.TournamentID = i.TournamentID
        JOIN Tournaments tn ON tn.TournamentID = m.TournamentID
        CROSS JOIN (
            SELECT HomeTeamID AS TeamID FROM inserted
            UNION
            SELECT AwayTeamID FROM inserted
        ) tm
        WHERE m.Status = 'Finished'
          AND (m.HomeTeamID = tm.TeamID OR m.AwayTeamID = tm.TeamID)
        GROUP BY tm.TeamID, m.TournamentID, tn.SeasonID
    )
    MERGE TeamSeasonStats AS tgt
    USING MatchAgg AS src
        ON tgt.TeamID = src.TeamID
       AND tgt.TournamentID = src.TournamentID
       AND tgt.SeasonID     = src.SeasonID
    WHEN MATCHED THEN
        UPDATE SET
            GamesPlayed  = src.GP,
            Wins         = src.W,
            Losses       = src.L,
            OTLosses     = src.OTL,
            Points       = src.W * 2 + src.OTL,
            GoalsFor     = src.GF,
            GoalsAgainst = src.GA
    WHEN NOT MATCHED THEN
        INSERT (TeamID, SeasonID, TournamentID, GamesPlayed, Wins, Losses, OTLosses, Points, GoalsFor, GoalsAgainst)
        VALUES (src.TeamID, src.SeasonID, src.TournamentID, src.GP, src.W, src.L, src.OTL, src.W*2+src.OTL, src.GF, src.GA);
END;
GO

-- ============================================================
-- 11. НАЧАЛЬНЫЕ СПРАВОЧНЫЕ ДАННЫЕ
-- ============================================================

INSERT INTO Positions (Name, ShortName) VALUES
    (N'Вратарь',    N'GK'),
    (N'Защитник',   N'D'),
    (N'Нападающий', N'F');

INSERT INTO CoachRoles (Name) VALUES
    (N'Главный тренер'),
    (N'Ассистент главного тренера'),
    (N'Тренер вратарей'),
    (N'Тренер по физической подготовке');

INSERT INTO EventTypes (Name, Category) VALUES
    (N'Гол',                     'Goal'),
    (N'Гол в большинстве',       'Goal'),
    (N'Гол в меньшинстве',       'Goal'),
    (N'Гол пустые ворота',       'Goal'),
    (N'Буллит (гол)',            'Goal'),
    (N'Малый штраф (2 мин)',     'Penalty'),
    (N'Большой штраф (5 мин)',   'Penalty'),
    (N'Дисциплинарный штраф',    'Penalty'),
    (N'Матч-штраф',              'Penalty'),
    (N'Замена',                  'Substitution'),
    (N'Тайм-аут',                'Other'),
    (N'Видеопросмотр',           'Other');
GO

PRINT N'База данных HockeyLeague успешно создана.';
GO