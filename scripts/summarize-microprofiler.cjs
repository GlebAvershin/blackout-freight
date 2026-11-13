// Usage: node scripts/summarize-microprofiler.cjs /path/to/LibMP.js capture.html [...]
const path = require('node:path');

async function main() {
  const [libraryPath, ...captures] = process.argv.slice(2);
  if (!libraryPath || captures.length === 0) {
    throw new Error('Usage: node scripts/summarize-microprofiler.cjs LibMP.js capture.html [...]');
  }

  const libmp = await require(path.resolve(libraryPath)).create();
  for (const capture of captures) {
    const session = await libmp.Session.OpenFromFile(capture);
    if (!session?.IsValid()) throw new Error(`Invalid MicroProfiler capture: ${capture}`);

    try {
      const { tickToMsCpu } = session.FetchGlobalDesc();
      const intervals = [];
      let previous;
      for (let id = session.GetFrameIdMin(); id <= session.GetFrameIdMax(); id++) {
        const frame = session.FetchFrameDesc(id);
        if (!frame || frame.isPaused || frame.isIncomplete) {
          previous = undefined;
          continue;
        }
        if (previous && frame.frameAbsoluteId === previous.id + 1) {
          const ms = Number(frame.tickStartCpu - previous.start) * tickToMsCpu;
          if (ms > 0 && Number.isFinite(ms)) intervals.push(ms);
        }
        previous = { id: frame.frameAbsoluteId, start: frame.tickStartCpu };
      }

      if (intervals.length === 0) throw new Error(`No consecutive complete frames: ${capture}`);
      const elapsedMs = intervals.reduce((sum, value) => sum + value, 0);
      intervals.sort((a, b) => a - b);
      const p95 = intervals[Math.ceil(intervals.length * 0.95) - 1];
      console.log(`${capture}: ${intervals.length} intervals, ${elapsedMs.toFixed(1)} ms, ` +
        `${(1000 * intervals.length / elapsedMs).toFixed(2)} FPS, ` +
        `p95 ${p95.toFixed(2)} ms, max ${intervals.at(-1).toFixed(2)} ms`);
    } finally {
      session.Dispose();
    }
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
