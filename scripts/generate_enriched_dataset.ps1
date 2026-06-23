param(
    [string]$ProjectRoot = "G:\data-analysis-portfolio\game-retention-analysis"
)

$ErrorActionPreference = "Stop"

$dataDir = Join-Path $ProjectRoot "data"
$rawPath = Join-Path $dataDir "cookie_cats.csv"
$profilePath = Join-Path $dataDir "game_user_profile_enriched.csv"
$activityPath = Join-Path $dataDir "game_daily_activity_simulated.csv"

if (-not (Test-Path -LiteralPath $rawPath)) {
    throw "Raw data file not found: $rawPath"
}

$rng = [System.Random]::new(202604)
$startDate = [DateTime]::ParseExact("2026-04-01", "yyyy-MM-dd", $null)

function BoolText([bool]$value) {
    if ($value) { return "True" }
    return "False"
}

function Get-ActivitySegment([int]$rounds) {
    if ($rounds -eq 0) { return "not_started" }
    if ($rounds -le 10) { return "light_player" }
    if ($rounds -le 50) { return "medium_player" }
    return "heavy_player"
}

function Get-Retention3([bool]$retention1, [bool]$retention7, [int]$rounds, [System.Random]$rng) {
    if ($retention7) { return $rng.NextDouble() -lt 0.92 }
    if (-not $retention1) {
        if ($rounds -ge 50) { return $rng.NextDouble() -lt 0.18 }
        if ($rounds -ge 10) { return $rng.NextDouble() -lt 0.08 }
        return $rng.NextDouble() -lt 0.02
    }
    if ($rounds -ge 100) { return $rng.NextDouble() -lt 0.72 }
    if ($rounds -ge 30) { return $rng.NextDouble() -lt 0.58 }
    if ($rounds -ge 10) { return $rng.NextDouble() -lt 0.42 }
    return $rng.NextDouble() -lt 0.25
}

function Get-LifecycleStage([int]$rounds, [bool]$retention1, [bool]$retention3, [bool]$retention7) {
    if ($rounds -eq 0) { return "not_started" }
    if (-not $retention1) { return "newbie_churn" }
    if (-not $retention3) { return "early_churn" }
    if (-not $retention7) { return "mid_term_churn" }
    return "stable_active"
}

function Get-CohortWeek([DateTime]$date) {
    $offset = ([int]$date.DayOfWeek + 6) % 7
    return $date.AddDays(-$offset).ToString("yyyy-MM-dd")
}

function Get-DayActivity([int]$day, [bool]$retention1, [bool]$retention3, [bool]$retention7, [int]$rounds, [System.Random]$rng) {
    if ($day -eq 0) { return $true }
    if ($day -eq 1) { return $retention1 }
    if ($day -eq 3) { return $retention3 }
    if ($day -eq 7) { return $retention7 }

    $baseProb = 0.08
    if ($retention7) { $baseProb = 0.70 }
    elseif ($retention3) { $baseProb = 0.45 }
    elseif ($retention1) { $baseProb = 0.28 }

    if ($rounds -ge 100) { $baseProb += 0.12 }
    elseif ($rounds -le 5) { $baseProb -= 0.05 }

    if ($baseProb -lt 0.02) { $baseProb = 0.02 }
    if ($baseProb -gt 0.95) { $baseProb = 0.95 }
    return $rng.NextDouble() -lt $baseProb
}

function Get-RetentionFlag([int]$day) {
    if ($day -eq 0) { return "D0" }
    if ($day -eq 1) { return "D1" }
    if ($day -eq 3) { return "D3" }
    if ($day -eq 7) { return "D7" }
    return ""
}

function Get-DayWeight([int]$day, [bool]$retention7, [System.Random]$rng) {
    $weight = 1.0 + $rng.NextDouble()
    if ($day -eq 0) { $weight *= 3.0 }
    elseif ($day -eq 1) { $weight *= 2.0 }
    elseif ($day -eq 7 -and $retention7) { $weight *= 1.6 }
    return $weight
}

function Get-RoundAllocations([int]$rounds, [int[]]$activeDays, [bool]$retention7, [System.Random]$rng) {
    $allocations = @{}
    foreach ($day in 0..7) { $allocations[$day] = 0 }
    if ($rounds -le 0 -or $activeDays.Count -eq 0) { return $allocations }

    $weightedRows = New-Object System.Collections.Generic.List[object]
    $weightSum = 0.0
    foreach ($day in $activeDays) {
        $weight = Get-DayWeight $day $retention7 $rng
        $weightSum += $weight
        $weightedRows.Add([PSCustomObject]@{
            Day = $day
            Weight = $weight
            Allocated = 0
            Remainder = 0.0
        })
    }

    $allocatedSum = 0
    foreach ($row in $weightedRows) {
        $rawAllocation = $rounds * $row.Weight / $weightSum
        $allocation = [Math]::Floor($rawAllocation)
        $row.Allocated = [int]$allocation
        $row.Remainder = $rawAllocation - $allocation
        $allocatedSum += [int]$allocation
    }

    $remaining = $rounds - $allocatedSum
    $rankedRows = $weightedRows | Sort-Object -Property Remainder -Descending
    $rankIndex = 0
    while ($remaining -gt 0) {
        $rankedRows[$rankIndex].Allocated += 1
        $remaining -= 1
        $rankIndex += 1
        if ($rankIndex -ge $rankedRows.Count) { $rankIndex = 0 }
    }

    foreach ($row in $weightedRows) {
        $allocations[$row.Day] = $row.Allocated
    }
    return $allocations
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$reader = [System.IO.StreamReader]::new($rawPath, [System.Text.Encoding]::UTF8)
$profileWriter = [System.IO.StreamWriter]::new($profilePath, $false, $utf8NoBom)
$activityWriter = [System.IO.StreamWriter]::new($activityPath, $false, $utf8NoBom)

$profileCount = 0
$activityCount = 0

try {
    $profileWriter.WriteLine("user_id,experiment_group,sum_gamerounds,retention_1,retention_3,retention_7,install_date,first_active_date,cohort_date,cohort_week,is_new_user,activity_segment,lifecycle_stage,is_churn_7d")
    $activityWriter.WriteLine("user_id,experiment_group,install_date,active_date,day_n,is_active,daily_game_rounds,activity_segment,retention_flag")

    [void]$reader.ReadLine()
    while (($line = $reader.ReadLine()) -ne $null) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = $line.Split(",")
        $userId = [int]$parts[0]
        $group = [string]$parts[1]
        $rounds = [int]$parts[2]
        $retention1 = [System.Convert]::ToBoolean($parts[3])
        $retention7 = [System.Convert]::ToBoolean($parts[4])
        $retention3 = Get-Retention3 $retention1 $retention7 $rounds $rng

        $installDate = $startDate.AddDays($rng.Next(0, 30))
        $installText = $installDate.ToString("yyyy-MM-dd")
        $cohortWeek = Get-CohortWeek $installDate
        $isNewUser = $rng.NextDouble() -lt 0.82
        $segment = Get-ActivitySegment $rounds
        $stage = Get-LifecycleStage $rounds $retention1 $retention3 $retention7
        $isChurn7d = -not $retention7

        $profileWriter.WriteLine(("{0},{1},{2},{3},{4},{5},{6},{6},{6},{7},{8},{9},{10},{11}" -f `
            $userId, $group, $rounds, (BoolText $retention1), (BoolText $retention3), (BoolText $retention7), `
            $installText, $cohortWeek, (BoolText $isNewUser), $segment, $stage, (BoolText $isChurn7d)))
        $profileCount += 1

        $activeDays = New-Object System.Collections.Generic.List[int]
        $dayActive = @{}
        foreach ($day in 0..7) {
            $isActive = Get-DayActivity $day $retention1 $retention3 $retention7 $rounds $rng
            $dayActive[$day] = $isActive
            if ($isActive) { $activeDays.Add($day) }
        }

        $allocations = Get-RoundAllocations $rounds $activeDays.ToArray() $retention7 $rng

        foreach ($day in 0..7) {
            $activeDate = $installDate.AddDays($day).ToString("yyyy-MM-dd")
            $activityWriter.WriteLine(("{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f `
                $userId, $group, $installText, $activeDate, $day, (BoolText $dayActive[$day]), $allocations[$day], $segment, (Get-RetentionFlag $day)))
            $activityCount += 1
        }
    }
}
finally {
    $reader.Close()
    $profileWriter.Close()
    $activityWriter.Close()
}

Write-Host "Generated:"
Write-Host "  $profilePath"
Write-Host "  $activityPath"
Write-Host "Rows:"
Write-Host "  user_profile=$profileCount"
Write-Host "  daily_activity=$activityCount"
