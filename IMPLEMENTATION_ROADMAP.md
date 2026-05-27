# ============================================================================
# IMPLEMENTATION ROADMAP & ISSUE TRACKER
# ============================================================================

## PHASE 1: CRITICAL SECURITY FIXES (Week 1)
**Must complete before ANY production use**

### Issue #1: Path Traversal & File Injection Vulnerability  
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 2-3 hours  
**Assignee**: [Security Engineer]  

- [ ] Implement filename sanitization function
- [ ] Add path validation to prevent escape
- [ ] Test with malicious filenames
- [ ] Update all file operations
- [ ] Add unit tests
- [ ] Code review

**Files to modify**: `backend/downloader.py`, `backend/main.py`  
**Testing**: `pytest backend/tests/test_security.py::test_path_traversal_blocked`

---

### Issue #2: CORS Misconfiguration - Open to All Origins
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 1 hour  
**Assignee**: [Backend Engineer]  

- [ ] Replace `allow_origins=["*"]` with whitelist
- [ ] Load allowed origins from environment
- [ ] Set `allow_credentials=False`
- [ ] Restrict HTTP methods to GET/POST
- [ ] Test CORS headers
- [ ] Update .env.example

**Files to modify**: `backend/main.py`, `backend/config.py`  
**Testing**: `curl -i -H "Origin: https://malicious.com" http://localhost:8000/api/health`

---

### Issue #3: SQLite Multi-threading Race Conditions
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 4-5 hours  
**Assignee**: [Database Engineer]  

- [ ] Option A: Migrate to PostgreSQL (RECOMMENDED)
  - [ ] Setup PostgreSQL locally
  - [ ] Update DATABASE_URL in config
  - [ ] Initialize database schema
  - [ ] Run data migration if needed
  - [ ] Update requirements.txt
  
- [ ] Option B: If must keep SQLite
  - [ ] Enable WAL mode
  - [ ] Add connection pooling
  - [ ] Implement optimistic locking
  - [ ] Add retry logic

**Files to modify**: `backend/models.py`, `backend/config.py`, `backend/requirements.txt`  
**Testing**: Load test with 10+ concurrent downloads

---

### Issue #4: WebSocket Memory Leak
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 2-3 hours  
**Assignee**: [Frontend Engineer]  

- [ ] Implement exponential backoff in reconnection
- [ ] Fix event listener cleanup in Dashboard.jsx
- [ ] Add reconnection attempt limits
- [ ] Test with network throttling
- [ ] Memory profiling with DevTools
- [ ] Add unit tests

**Files to modify**: `frontend/src/hooks/useWebSocket.js`, `frontend/src/pages/Dashboard.jsx`  
**Testing**: Devtools Memory tab - verify no listener accumulation after 10+ reconnects

---

### Issue #5: Database Session Management & Resource Leaks
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 3 hours  
**Assignee**: [Backend Engineer]  

- [ ] Implement context manager for DB sessions
- [ ] Fix all SessionLocal() calls in downloader.py
- [ ] Add proper try/except/finally
- [ ] Test with concurrent requests
- [ ] Add connection monitoring

**Files to modify**: `backend/downloader.py`, `backend/models.py`  
**Testing**: Monitor open connections under load: `SELECT count(*) FROM pg_stat_activity;`

---

### Issue #6: Input Validation - No Sanitization
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 2-3 hours  
**Assignee**: [Backend Engineer]  

- [ ] Create Pydantic validators for all inputs
- [ ] Validate URL format and length
- [ ] Sanitize song names
- [ ] Add max_items constraints
- [ ] Write unit tests
- [ ] Document API contracts

**Files to modify**: `backend/main.py`  
**Testing**: `pytest backend/tests/test_validation.py`

---

### Issue #7: Silent Exception Handling
**Severity**: CRITICAL | **Status**: Not Started  
**Time**: 2 hours  
**Assignee**: [Backend Engineer]  

- [ ] Replace all bare `except:` with proper exceptions
- [ ] Implement structured logging
- [ ] Remove print() statements
- [ ] Add logging module to all files
- [ ] Configure log rotation
- [ ] Test log output in production

**Files to modify**: All `backend/*.py` files  
**Testing**: `grep -r "except:" backend/ --include="*.py"`

---

## PHASE 2: HIGH SEVERITY ISSUES (Week 2)

### Issue #8: ThreadPoolExecutor Never Shutdown
**Severity**: HIGH | **Status**: Not Started  
**Time**: 1.5 hours  

- [ ] Wrap executor in class with shutdown method
- [ ] Register shutdown in FastAPI lifespan
- [ ] Test cleanup on app shutdown
- [ ] Monitor thread count

**Files to modify**: `backend/providers_youtube.py`, `backend/main.py`

---

### Issue #9: Hardcoded API Endpoints
**Severity**: HIGH | **Status**: Not Started  
**Time**: 2 hours  

- [ ] Create API URL utility functions
- [ ] Use environment variables everywhere
- [ ] Test with different VITE_API_URL values
- [ ] Update frontend build process

**Files to modify**: Frontend React components, `frontend/vite.config.js`

---

### Issue #10: No Rate Limiting
**Severity**: HIGH | **Status**: Not Started  
**Time**: 2 hours  

- [ ] Add slowapi to requirements
- [ ] Configure rate limits per endpoint
- [ ] Test rate limiting
- [ ] Add monitoring/alerts

**Files to modify**: `backend/main.py`, `backend/requirements-prod.txt`

---

### Issue #11: Broken CI/CD Pipeline
**Severity**: HIGH | **Status**: Not Started  
**Time**: 3 hours  

- [ ] Rewrite GitHub Actions workflow
- [ ] Add real backend tests
- [ ] Add frontend build validation
- [ ] Setup security scanning
- [ ] Test Docker image building

**Files to modify**: `.github/workflows/ci.yml`

---

### Issue #12: No Error Boundary in React
**Severity**: HIGH | **Status**: Not Started  
**Time**: 1 hour  

- [ ] Create ErrorBoundary component
- [ ] Wrap App with ErrorBoundary
- [ ] Test error handling
- [ ] Setup error logging

**Files to modify**: `frontend/src/components/ErrorBoundary.jsx`, `frontend/src/main.jsx`

---

### Issue #13: Tailwind Dynamic Classes Won't Purge
**Severity**: HIGH | **Status**: Not Started  
**Time**: 0.5 hours  

- [ ] Fix ProgressCard component
- [ ] Use static class names
- [ ] Test Tailwind build

**Files to modify**: `frontend/src/components/ProgressCard.jsx`

---

## PHASE 3: MEDIUM SEVERITY ISSUES (Week 3)

### Issue #14: Windows Path Handling
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 1 hour  

- [ ] Replace manual path manipulation with Path
- [ ] Test on Windows
- [ ] Test symlink handling

---

### Issue #15: React Key Warnings
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 0.5 hours  

- [ ] Replace index as key with unique identifiers
- [ ] Fix SongList component
- [ ] Run React DevTools to verify

---

### Issue #16: Incomplete Implementations
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 2 hours  

- [ ] Implement SoundCloud provider properly or remove
- [ ] Remove unimplemented Audius mention
- [ ] Remove unimplemented Mr-Jatt mention
- [ ] Update documentation

---

### Issue #17: Database in Repository
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 0.5 hours  

- [ ] Add *.db to .gitignore
- [ ] Remove music_downloader.db from git
- [ ] Create schema.sql for initialization

```bash
git rm --cached backend/music_downloader.db
git commit -m "Remove database from repository"
```

---

### Issue #18: Production Database Selection
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 4 hours  

- [ ] Setup PostgreSQL development environment
- [ ] Create migration scripts
- [ ] Test with production data
- [ ] Document deployment

---

## PHASE 4: TESTING & QUALITY (Week 3)

### Issue #19: Add Unit Tests
**Severity**: HIGH | **Status**: Not Started  
**Time**: 8 hours  
**Target**: 70% code coverage

**Testing Files to Create**:
- [ ] `backend/tests/test_security.py` - Security validations
- [ ] `backend/tests/test_downloader.py` - Download manager
- [ ] `backend/tests/test_api.py` - API endpoints
- [ ] `backend/tests/test_providers.py` - Provider searches
- [ ] `frontend/src/__tests__/useWebSocket.test.js` - WebSocket hook

**Commands**:
```bash
pytest --cov=backend backend/tests/
npm test --coverage
```

---

### Issue #20: Integration Tests
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 5 hours  

- [ ] Test full playlist extraction -> download flow
- [ ] Test database persistence
- [ ] Test WebSocket communication
- [ ] Test error scenarios

---

### Issue #21: Load Testing
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 3 hours  

- [ ] Setup Locust for load testing
- [ ] Test 100 concurrent users
- [ ] Test 1000 concurrent downloads
- [ ] Measure response times

```python
# locustfile.py
from locust import HttpUser, task, between

class MusicDownloaderUser(HttpUser):
    wait_time = between(1, 3)
    
    @task
    def extract_playlist(self):
        self.client.post("/api/extract-playlist", 
            json={"url": "https://music.apple.com/..."})
```

---

## PHASE 5: PRODUCTION DEPLOYMENT (Week 4)

### Issue #22: Docker Setup
**Severity**: HIGH | **Status**: Not Started  
**Time**: 3 hours  

- [ ] Create Dockerfile.backend
- [ ] Create Dockerfile.frontend
- [ ] Create docker-compose.prod.yml
- [ ] Test Docker builds
- [ ] Document Docker usage

---

### Issue #23: Environment Configuration
**Severity**: HIGH | **Status**: Not Started  
**Time**: 2 hours  

- [ ] Create .env.example with all options
- [ ] Document all environment variables
- [ ] Setup environment validation
- [ ] Test with different environments

---

### Issue #24: Logging & Monitoring
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 4 hours  

- [ ] Setup structured logging (JSON)
- [ ] Setup centralized log aggregation
- [ ] Setup error tracking (Sentry)
- [ ] Setup performance monitoring

---

### Issue #25: Security Headers & HTTPS
**Severity**: HIGH | **Status**: Not Started  
**Time**: 2 hours  

- [ ] Add security headers middleware
- [ ] Setup HTTPS/WSS
- [ ] Configure SSL certificates
- [ ] Test with security scanners

---

### Issue #26: Database Backups
**Severity**: MEDIUM | **Status**: Not Started  
**Time**: 2 hours  

- [ ] Create backup script
- [ ] Setup automated backups
- [ ] Test restore procedures
- [ ] Document backup process

---

## PRIORITY IMPLEMENTATION ORDER

**Day 1** (Critical):
1. Issue #1 - Path traversal fix ⚠️
2. Issue #2 - CORS fix ⚠️
3. Issue #7 - Logging

**Day 2-3** (Critical):
4. Issue #3 - Database setup
5. Issue #4 - WebSocket memory leak
6. Issue #5 - Database sessions
7. Issue #6 - Input validation

**Day 4-5** (High):
8. Issue #8-10 - Various high severity
9. Issue #11 - CI/CD

**Week 2-3** (Medium + Testing):
10. Issues #12-21 - Medium severity + tests
11. Issue #22-26 - Production setup

---

## SUCCESS METRICS

- [ ] All CRITICAL issues resolved
- [ ] Security audit passes
- [ ] Unit tests: 70%+ coverage
- [ ] Integration tests: All pass
- [ ] Load testing: 1000+ concurrent users
- [ ] Zero errors in logs for 24h
- [ ] OWASP ZAP scan: Clean
- [ ] All security headers present
- [ ] Database backup/restore working
- [ ] Monitoring & alerts configured
- [ ] Documentation complete
- [ ] Deployment guide tested
- [ ] Incident response runbook ready

---

## TRACKING TEMPLATE

For each issue, create a GitHub Issue with:

```markdown
## [ISSUE NAME]
- **Severity**: CRITICAL/HIGH/MEDIUM
- **Status**: Not Started / In Progress / Testing / Done
- **Assignee**: [Name]
- **Due Date**: [Date]
- **Estimated Time**: [Hours]

## Description
[Full description]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Testing Plan
[How to test]

## Files Changed
- file1.py
- file2.py
```

---

## NOTES

- All CRITICAL issues must be completed before production deployment
- Re-estimate if issues take >20% longer than expected
- Daily standup to track progress
- Code review required for all changes
- All tests must pass before merge

Last Updated: 2024-12-05
