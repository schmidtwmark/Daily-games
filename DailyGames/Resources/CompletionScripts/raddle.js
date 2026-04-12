(function() {
    try {
        var text = document.body.innerText || '';

        // Check for "Share results" in body text
        if (text.includes('Share results')) {
            var result = { completed: true, won: true };

            // Extract hint-free percentage
            // Look for patterns like "80% without hints", "100% hint-free", "X% of clues without hints"
            var hintMatch = text.match(/(\d+)%\s*(?:without\s*hints|hint[- ]free|of\s*clues\s*(?:guessed\s*)?without\s*hints)/i);
            if (hintMatch) {
                result.hintFreePercent = parseInt(hintMatch[1], 10);
            }

            // Also try matching "X/Y without hints" and calculate percentage
            if (!result.hintFreePercent) {
                var fractionMatch = text.match(/(\d+)\s*\/\s*(\d+)\s*(?:without\s*hints|hint[- ]free)/i);
                if (fractionMatch) {
                    var num = parseInt(fractionMatch[1], 10);
                    var den = parseInt(fractionMatch[2], 10);
                    if (den > 0) {
                        result.hintFreePercent = Math.round((num / den) * 100);
                    }
                }
            }

            return JSON.stringify(result);
        }
    } catch(e) {
        console.error('Raddle completion detection error:', e);
    }
    return JSON.stringify({ completed: false, won: false });
})();
