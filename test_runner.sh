#!/bin/bash

# Try to run mix test with reduced dependencies
# First, create a minimal lock if network is unavailable

# Check if we can find a GitHub Actions log with a working mix.lock
cd /home/runner/work/casbin-ex/casbin-ex

# Try running with git to see if there's cached deps that work
echo "Attempting to use cached dependencies..."

# Check if we have git origin
git remote -v 2>/dev/null | head -5

# Let's check the original branch to see what was working
echo "Checking git log for working test runs..."
git log --oneline -10 2>/dev/null || echo "Git history not available"

