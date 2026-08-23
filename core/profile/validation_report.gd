extends RefCounted
class_name ValidationReport


##
## ValidationReport
##
## Reúne ValidationIssues sin modificar
## los objetos recibidos.
##


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _issues: Array[ValidationIssue] = []


# =============================================================================
# CONSTRUCTION API
# =============================================================================

func add_issue(
	issue: ValidationIssue
) -> bool:

	if issue == null:
		return false

	if _issues.has(issue):
		return false

	_issues.append(issue)

	return true


# =============================================================================
# QUERY API
# =============================================================================

func get_issues() -> Array[ValidationIssue]:

	return _issues.duplicate()


func get_issue_count() -> int:

	return _issues.size()


func is_empty() -> bool:

	return _issues.is_empty()


func has_severity(
	severity: ValidationIssue.Severity
) -> bool:

	for issue: ValidationIssue in _issues:

		if issue.get_severity() == severity:
			return true

	return false


func is_valid_for_simulation() -> bool:

	return (
		not has_severity(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR
		)
		and not has_severity(
			ValidationIssue.Severity
				.PLATFORM_SAFETY_ERROR
		)
	)


func is_valid_for_hardware() -> bool:

	return (
		not has_severity(
			ValidationIssue.Severity
				.SIMULATION_HAZARD
		)
		and not has_severity(
			ValidationIssue.Severity
				.STRUCTURAL_ERROR
		)
		and not has_severity(
			ValidationIssue.Severity
				.PLATFORM_SAFETY_ERROR
		)
		and not has_severity(
			ValidationIssue.Severity
				.HARDWARE_SAFETY_ERROR
		)
	)
