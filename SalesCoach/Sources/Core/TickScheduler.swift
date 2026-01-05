import Foundation
import Combine

/// Scheduler for periodic coaching analysis ticks
actor TickScheduler {
    private var timer: Timer?
    private var isRunning = false
    private var lastTickTime: Date?
    private var isPreviousTickRunning = false
    
    /// Interval between ticks in seconds
    let intervalSeconds: Int
    
    /// Callback for tick events
    private var onTick: (() async -> Void)?
    
    /// Callback to check if tick should be skipped
    private var shouldSkipTick: (() async -> Bool)?
    
    /// Set the tick handler
    func setTickHandler(_ handler: @escaping () async -> Void) {
        onTick = handler
    }
    
    /// Set the skip check handler
    func setSkipCheck(_ handler: @escaping () async -> Bool) {
        shouldSkipTick = handler
    }
    
    init(intervalSeconds: Int = 7) {
        self.intervalSeconds = intervalSeconds
    }
    
    /// Start the scheduler
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        lastTickTime = nil
        
        scheduleNextTick()
    }
    
    /// Stop the scheduler
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Pause the scheduler
    func pause() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Resume the scheduler
    func resume() {
        guard isRunning else { return }
        scheduleNextTick()
    }
    
    private func scheduleNextTick() {
        timer?.invalidate()
        
        // Schedule on main RunLoop to ensure timer fires
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task {
                let interval = await self.intervalSeconds
                let newTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
                    Task { [weak self] in
                        await self?.tick()
                    }
                }
                RunLoop.main.add(newTimer, forMode: .common)
                await self.setTimer(newTimer)
            }
        }
    }
    
    private func setTimer(_ newTimer: Timer) {
        timer = newTimer
    }
    
    private func tick() async {
        guard isRunning else { return }
        
        // Skip if previous tick is still running
        guard !isPreviousTickRunning else {
            return
        }
        
        // Check if we should skip this tick
        if let shouldSkip = shouldSkipTick, await shouldSkip() {
            return
        }
        
        isPreviousTickRunning = true
        lastTickTime = Date()
        
        // Execute tick callback
        await onTick?()
        
        isPreviousTickRunning = false
    }
    
    /// Time until next tick in seconds
    var timeUntilNextTick: TimeInterval {
        guard let lastTick = lastTickTime else {
            return TimeInterval(intervalSeconds)
        }
        
        let elapsed = Date().timeIntervalSince(lastTick)
        return max(0, TimeInterval(intervalSeconds) - elapsed)
    }
    
    /// Whether a tick is currently being processed
    var isTickInProgress: Bool {
        isPreviousTickRunning
    }
}

