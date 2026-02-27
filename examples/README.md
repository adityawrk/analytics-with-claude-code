# Examples

Complete, self-contained analytics workflows demonstrating Claude Code in action. For a working example right now, see the [demo/](../demo/) directory which runs with DuckDB and sample data out of the box.

Each example below describes a scenario and walkthrough. **Contributions welcome** -- these need sample data files to be fully runnable. See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Available Examples

### [EDA Workflow](eda-workflow/)
**Scenario:** You've received a new dataset and need to understand it before analysis.
- Profile the dataset structure and quality
- Identify distributions, outliers, and relationships
- Generate a comprehensive EDA report
- **Skills used:** `/eda`, `/data-quality`

### [A/B Test Analysis](ab-test-analysis/)
**Scenario:** The product team ran an experiment and needs a rigorous statistical analysis.
- Validate experimental setup (sample sizes, randomization)
- Calculate metrics per variant
- Run significance tests
- Generate a recommendation report
- **Skills used:** `/ab-test`, `/report-generator`

### [dbt Project](dbt-project/)
**Scenario:** Build a set of dbt models for a new data source from scratch.
- Explore the source data
- Create staging, intermediate, and mart models
- Add tests and documentation
- **Agents used:** `data-explorer`, `pipeline-builder`

### [Dashboard Generation](dashboard-generation/)
**Scenario:** Create a weekly metrics dashboard from database queries.
- Define key metrics and dimensions
- Write the underlying queries
- Generate the formatted report
- **Skills used:** `/metric-calculator`, `/report-generator`
