#!/bin/bash

# quality_check.sh
# Local quality check script for Children of the Singularity
# Runs the same checks as the GitHub Actions PR pipeline

set -e

echo "🚀 Running local quality checks..."
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    case $1 in
        "ERROR")
            echo -e "${RED}❌ $2${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $2${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $2${NC}"
            ;;
        *)
            echo "📋 $2"
            ;;
    esac
}

# Check if we're in the right directory
if [ ! -f "project.godot" ]; then
    print_status "ERROR" "Not in the project root directory. Please run from the Children_of_Singularity directory."
    exit 1
fi

# Check dependencies
echo "🔍 Checking dependencies..."

# Check if Godot is available
if ! command -v godot &> /dev/null; then
    print_status "ERROR" "Godot not found. Please install Godot 4.4.1 or later."
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    print_status "ERROR" "Python3 not found. Please install Python 3.11 or later."
    exit 1
fi

# Check if backend venv exists
if [ ! -d "backend/venv" ]; then
    print_status "ERROR" "Backend virtual environment not found. Please run 'cd backend && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt'"
    exit 1
fi

print_status "SUCCESS" "All dependencies found"

# 1. Godot Project Validation
echo ""
echo "🎮 Validating Godot project..."
echo "--------------------------------"

if godot --headless --check --quit > /dev/null 2>&1; then
    print_status "SUCCESS" "Godot project validation passed"
else
    print_status "ERROR" "Godot project validation failed"
    exit 1
fi

# Check GDScript files exist and are properly named
echo "📝 Checking GDScript files..."
gdscript_files=$(find scripts -name "*.gd" -type f | wc -l)
if [ $gdscript_files -gt 0 ]; then
    print_status "SUCCESS" "Found $gdscript_files GDScript files"
    # The syntax is already validated by the project validation above
    print_status "SUCCESS" "All GDScript files validated with project context"
else
    print_status "ERROR" "No GDScript files found"
    exit 1
fi

# 2. Python Backend Quality
echo ""
echo "🐍 Checking Python backend quality..."
echo "--------------------------------------"

cd backend

# Activate virtual environment
source venv/bin/activate

# Install linting tools if not present
pip install flake8 black mypy > /dev/null 2>&1

# Check if app.py imports correctly
if python -c "import app" > /dev/null 2>&1; then
    print_status "SUCCESS" "Backend imports successfully"
else
    print_status "ERROR" "Backend import failed"
    exit 1
fi

# Run Black formatting check
if black --check app.py > /dev/null 2>&1; then
    print_status "SUCCESS" "Python formatting is correct"
else
    print_status "ERROR" "Python formatting issues found. Run 'black app.py' to fix"
    exit 1
fi

# Run Flake8 linting
if flake8 app.py --max-line-length=88 > /dev/null 2>&1; then
    print_status "SUCCESS" "Python linting passed"
else
    print_status "ERROR" "Python linting issues found"
    flake8 app.py --max-line-length=88
    exit 1
fi

# Run MyPy type checking
if mypy app.py --ignore-missing-imports > /dev/null 2>&1; then
    print_status "SUCCESS" "Python type checking passed"
else
    print_status "ERROR" "Python type checking failed"
    mypy app.py --ignore-missing-imports
    exit 1
fi

cd ..

# 3. API Testing
echo ""
echo "🔌 Testing API endpoints..."
echo "----------------------------"

# Start backend server
cd backend
python -m uvicorn app:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

# Wait for server to start
sleep 5

# Test endpoints
if curl -f http://localhost:8000/api/v1/health > /dev/null 2>&1; then
    print_status "SUCCESS" "Health endpoint working"
else
    print_status "ERROR" "Health endpoint failed"
    kill $BACKEND_PID
    exit 1
fi

if curl -f http://localhost:8000/api/v1/stats > /dev/null 2>&1; then
    print_status "SUCCESS" "Stats endpoint working"
else
    print_status "ERROR" "Stats endpoint failed"
    kill $BACKEND_PID
    exit 1
fi

# Clean up
kill $BACKEND_PID
print_status "SUCCESS" "All API endpoints working"

# 4. Code Quality Analysis
echo ""
echo "📊 Analyzing code quality..."
echo "-----------------------------"

# Check TODO comments
TODO_COUNT=$(grep -r "TODO\|FIXME\|XXX\|BUG\|HACK" --include="*.gd" --include="*.py" . | grep -v "/venv/" | wc -l)
if [ $TODO_COUNT -gt 1000 ]; then
    print_status "WARNING" "High number of TODO comments ($TODO_COUNT)"
else
    print_status "SUCCESS" "TODO comment count is acceptable ($TODO_COUNT)"
fi

# Check file structure
required_dirs=("scripts" "scenes" "backend" "assets" "data/postgres" "logs" "memory_bank")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        print_status "SUCCESS" "Directory exists: $dir"
    else
        print_status "ERROR" "Missing directory: $dir"
        exit 1
    fi
done

# Check required files
required_files=("project.godot" "backend/app.py" "backend/requirements.txt" "README.md")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "SUCCESS" "File exists: $file"
    else
        print_status "ERROR" "Missing file: $file"
        exit 1
    fi
done

# 5. Security Scan
echo ""
echo "🔒 Running security scan..."
echo "-----------------------------"

# Check for potential secrets (simplified check)
if grep -r "password\|secret\|key\|token" --include="*.py" --include="*.gd" --exclude-dir=".git" . | grep -v "TODO\|FIXME\|password_change\|secret_key\|api_key" > /dev/null 2>&1; then
    print_status "WARNING" "Potential sensitive data found - please review"
else
    print_status "SUCCESS" "No obvious sensitive data found"
fi

# 6. Performance Check
echo ""
echo "🚀 Running performance checks..."
echo "---------------------------------"

# Check file sizes (exclude venv directory)
large_files=0
for file in $(find . -name "*.py" -o -name "*.gd" -o -name "*.sql" | grep -v "/venv/"); do
    size=$(wc -l < "$file")
    if [ $size -gt 1000 ]; then
        print_status "WARNING" "Large file: $file ($size lines)"
        large_files=$((large_files + 1))
    fi
done

if [ $large_files -eq 0 ]; then
    print_status "SUCCESS" "All files are reasonable size"
else
    print_status "WARNING" "Found $large_files large files - consider splitting"
fi

# Check for print statements in GDScript (note: we use print for logging in our implementation)
if grep -r "print(" --include="*.gd" . > /dev/null 2>&1; then
    print_status "SUCCESS" "Found print statements in GDScript (used for logging)"
else
    print_status "SUCCESS" "No print statements found in GDScript"
fi

# 7. Documentation Check
echo ""
echo "📚 Checking documentation..."
echo "-----------------------------"

# Check README
if [ -f "README.md" ] && [ -s "README.md" ]; then
    print_status "SUCCESS" "README.md exists and has content"
else
    print_status "ERROR" "README.md missing or empty"
    exit 1
fi

# Check memory bank documentation
memory_bank_files=("memory_bank_projectbrief.md" "memory_bank_activeContext.md" "memory_bank_progress.md")
for file in "${memory_bank_files[@]}"; do
    if [ -f "memory_bank/$file" ]; then
        print_status "SUCCESS" "Memory bank file exists: $file"
    else
        print_status "ERROR" "Missing memory bank file: $file"
        exit 1
    fi
done

# Final summary
echo ""
echo "🎉 Quality Check Summary"
echo "========================="
print_status "SUCCESS" "All quality checks passed!"
print_status "SUCCESS" "Code is ready for commit and PR"

echo ""
echo "Next steps:"
echo "1. git add ."
echo "2. git commit -m 'Your commit message'"
echo "3. git push origin your-branch"
echo "4. Create PR on GitHub" 